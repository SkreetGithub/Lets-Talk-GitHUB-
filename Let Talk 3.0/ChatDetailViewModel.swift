import SwiftUI
import Combine
import AVFoundation
import CoreLocation


class ChatDetailViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var isRecording = false
    @Published var selectedImage: UIImage?
    @Published var selectedDocument: URL?
    @Published var selectedLocation: CLLocationCoordinate2D?
    @Published var selectedContact: Contact?
    @Published var error: Error?
    /// Shown to the user as an alert when set.
    @Published var errorMessage: String?
    @Published var contact: Contact
    
    private let chat: Chat
    private let databaseManager = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var audioRecorder: AVAudioRecorder?
    private var audioRecordingURL: URL?
    /// Messages sent from this phone that the server hasn't returned yet (shown right away).
    private var pending: [Message] = []
    /// Read receipts already attempted, so each poll doesn't resend them all.
    private var readReceiptsSent: Set<String> = []
    
    /// The other person in this 1:1 chat: who every message here is addressed to.
    /// (Messages used to go to `contact.id`, which could still be a random placeholder ID.)
    var otherUserId: String {
        let me = AuthManager.shared.currentUserId?.lowercased()
        return chat.participants.first { $0.lowercased() != me } ?? contact.id
    }
    
    var messageGroups: [Date: [Message]] {
        Dictionary(grouping: messages) { message in
            Calendar.current.startOfDay(for: message.timestamp)
        }
    }
    
    init(chat: Chat) {
        self.chat = chat
        let me = AuthManager.shared.currentUserId?.lowercased()
        let otherId = chat.participants.first { $0.lowercased() != me } ?? ""
        // Show the saved contact's name immediately; the profile below fills in the rest.
        let saved = ContactManager.shared.contacts.first { $0.userId?.lowercased() == otherId.lowercased() }
        var placeholder = Contact(id: otherId, name: saved?.name ?? "", phone: saved?.phone ?? "", email: saved?.email ?? "")
        placeholder.userId = otherId
        self.contact = placeholder
        loadContact()
    }
    
    private func loadContact() {
        let contactId = otherUserId
        guard !contactId.isEmpty else { return }
        
        Task {
            do {
                let user = try await databaseManager.getUser(id: contactId)
                await MainActor.run {
                    var loaded = Contact(
                        id: contactId,
                        name: user.name,
                        phone: user.phone,
                        email: user.email,
                        lastMessage: nil,
                        image: nil
                    )
                    loaded.userId = contactId
                    loaded.imageURL = user.photoURL
                    self.contact = loaded
                }
            } catch {
                // Keep the saved name; the chat still works without the profile.
                debugLog("Couldn't load chat profile: \(error)")
            }
        }
    }
    
    func startListening() {
        databaseManager.listenForMessages(in: chat.id)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    Task { @MainActor in
                        self.error = error
                    }
                }
            } receiveValue: { [weak self] messages in
                guard let self else { return }
                // Keep messages that are still sending (or failed) on screen until the server has them.
                let serverIds = Set(messages.map(\.id))
                self.pending.removeAll { serverIds.contains($0.id) }
                self.messages = (messages + self.pending).sorted { $0.timestamp < $1.timestamp }
                self.markMessagesAsRead(messages)
                // Incoming messages are shown in my language (translated on this phone).
                Task { @MainActor in
                    MessageTranslator.shared.translateIncoming(messages, myUserId: AuthManager.shared.currentUserId)
                }
            }
            .store(in: &cancellables)
    }
    
    func stopListening() {
        cancellables.removeAll()
    }
    
    private func markMessagesAsRead(_ messages: [Message]) {
        let unreadMessages = messages.filter { message in
            message.senderId != AuthManager.shared.currentUserId &&
            message.status != .read &&
            !readReceiptsSent.contains(message.id)
        }
        
        guard !unreadMessages.isEmpty else { return }
        readReceiptsSent.formUnion(unreadMessages.map(\.id))
        
        Task {
            try? await databaseManager.markMessagesAsRead(unreadMessages.map { $0.id })
        }
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        guard let currentUserId = AuthManager.shared.currentUserId, !currentUserId.isEmpty else {
            debugLog("Error: User not authenticated")
            return
        }
        
        let receiverId = otherUserId
        guard !receiverId.isEmpty else {
            errorMessage = "This chat has no recipient. Close it and start it again from Contacts."
            return
        }
        
        var message = Message(
            senderId: currentUserId,
            receiverId: receiverId,
            content: messageText.trimmingCharacters(in: .whitespacesAndNewlines),
            type: .text
        )
        // Tell the receiver which language this is in, so their phone can skip or target translation.
        message.metadata = ["lang": SettingsManager.shared.settings.language]
        
        send(message)
        messageText = ""
    }
    
    func sendImage() {
        guard let image = selectedImage else { return }
        
        Task {
            do {
                let messageId = UUID().uuidString
                let url = try await uploadImage(image, messageId: messageId)
                let attachment = Message.Attachment(
                    id: messageId,
                    url: url,
                    type: .image,
                    size: Int(image.jpegData(compressionQuality: 0.8)?.count ?? 0),
                    name: "Image"
                )
                
                let message = Message(
                    senderId: AuthManager.shared.currentUserId ?? "",
                    receiverId: otherUserId,
                    content: "Sent an image",
                    type: .image,
                    attachments: [attachment]
                )
                
                send(message)
                await MainActor.run { self.selectedImage = nil }
            } catch {
                await MainActor.run {
                    self.selectedImage = nil
                    self.errorMessage = "Couldn't send the photo. Please try again."
                }
            }
        }
    }
    
    func sendDocument() {
        guard let url = selectedDocument else { return }
        
        Task {
            do {
                let messageId = UUID().uuidString
                let uploadedURL = try await uploadDocument(url, messageId: messageId)
                let attachment = Message.Attachment(
                    id: messageId,
                    url: uploadedURL,
                    type: .document,
                    size: try await url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0,
                    name: url.lastPathComponent
                )
                
                let message = Message(
                    senderId: AuthManager.shared.currentUserId ?? "",
                    receiverId: otherUserId,
                    content: "Sent a document",
                    type: .file,
                    attachments: [attachment]
                )
                
                send(message)
                await MainActor.run { self.selectedDocument = nil }
            } catch {
                await MainActor.run {
                    self.selectedDocument = nil
                    self.errorMessage = "Couldn't send the file. Please try again."
                }
            }
        }
    }
    
    func sendLocation() {
        guard let location = selectedLocation else { return }
        
        let message = Message(
            senderId: AuthManager.shared.currentUserId ?? "",
            receiverId: otherUserId,
            content: "\(location.latitude),\(location.longitude)",
            type: .location
        )
        
        send(message)
        selectedLocation = nil
    }
    
    func sendContact() {
        guard let shared = selectedContact else { return }
        
        guard let contactData = try? JSONEncoder().encode(shared),
              let contactString = String(data: contactData, encoding: .utf8) else {
            return
        }
        
        let message = Message(
            senderId: AuthManager.shared.currentUserId ?? "",
            receiverId: otherUserId,
            content: contactString,
            type: .contact
        )
        
        send(message)
        selectedContact = nil
    }
    
    /// Mic button in the composer: first tap records, second tap sends the voice message.
    func toggleRecording() {
        if isRecording {
            stopRecording()
            return
        }
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    self.startRecording()
                } else {
                    self.errorMessage = "Microphone access is off for Let Talk. Turn it on in Settings › Let Talk › Microphone to send voice messages."
                }
            }
        }
    }
    
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            audioRecordingURL = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioRecordingURL!, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            errorMessage = "Couldn't start recording. Please try again."
            isRecording = false
        }
    }
    
    func stopRecording() {
        let duration = audioRecorder?.currentTime ?? 0
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        guard let url = audioRecordingURL else { return }
        audioRecordingURL = nil
        guard duration >= 0.5 else { return }   // a tap-tap isn't a message
        
        Task {
            do {
                let messageId = UUID().uuidString
                let uploadedURL = try await uploadAudio(url, messageId: messageId)
                let attachment = Message.Attachment(
                    id: messageId,
                    url: uploadedURL,
                    type: .audio,
                    size: try await url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0,
                    name: "Voice Message"
                )
                
                let message = Message(
                    senderId: AuthManager.shared.currentUserId ?? "",
                    receiverId: otherUserId,
                    content: "Sent a voice message",
                    type: .audio,
                    attachments: [attachment]
                )
                
                send(message)
            } catch {
                await MainActor.run { self.errorMessage = "Couldn't send the voice message. Please try again." }
            }
        }
    }
    
    private func send(_ message: Message) {
        // Show it right away as "sending"; the next poll replaces it with the saved copy.
        var local = message
        local.status = .sending
        DispatchQueue.main.async {
            self.pending.append(local)
            self.messages.append(local)
        }
        Task {
            do {
                var saved = message
                saved.status = .sent
                try await databaseManager.sendMessage(saved)
                await MainActor.run { self.updatePending(message.id, status: .sent) }
            } catch {
                debugLog("Send failed: \(error)")
                await MainActor.run {
                    self.updatePending(message.id, status: .failed)
                    self.errorMessage = "Your message wasn't sent. Check your connection and try again."
                }
                return
            }
            // Notify the receiver (their notification shows the message in their language).
            // Best effort: the message is already saved, so a failed push changes nothing.
            try? await Backend.sendMessagePush(messageId: message.id)
        }
    }
    
    private func updatePending(_ id: String, status: Message.MessageStatus) {
        if let i = pending.firstIndex(where: { $0.id == id }) { pending[i].status = status }
        if let i = messages.firstIndex(where: { $0.id == id }), messages[i].status == .sending || status == .failed {
            messages[i].status = status
        }
    }
    
    /// Sends a failed message again.
    func retry(_ message: Message) {
        pending.removeAll { $0.id == message.id }
        messages.removeAll { $0.id == message.id }
        var copy = Message(senderId: message.senderId, receiverId: otherUserId, content: message.content,
                           type: message.type, attachments: message.attachments)
        copy.metadata = message.metadata
        send(copy)
    }
    
    // The chat's other participant IS a Let Talk user: call their user ID directly.
    // (This used to pass contact.phone as the callee ID, so the other phone never rang.)
    func startAudioCall() {
        startCall(isVideo: false)
    }
    
    func startVideoCall() {
        startCall(isVideo: true)
    }
    
    private func startCall(isVideo: Bool) {
        let otherUserId = chat.participants.first { $0 != AuthManager.shared.currentUserId }
        Task { @MainActor in
            if let otherUserId {
                CallCoordinator.shared.startCall(toUserId: otherUserId, isVideo: isVideo)
            } else {
                CallCoordinator.shared.startCall(to: contact, isVideo: isVideo)
            }
        }
    }
    
    private func uploadImage(_ image: UIImage, messageId: String) async throws -> String {
        return try await SupabaseStorageService.shared.uploadChatImage(image, chatId: chat.id, messageId: messageId)
    }
    
    private func uploadDocument(_ url: URL, messageId: String) async throws -> String {
        let data = try Data(contentsOf: url)
        let fileName = "\(messageId)_\(url.lastPathComponent)"
        return try await SupabaseStorageService.shared.uploadFile(
            data,
            fileName: fileName,
            folder: "chat_files/\(chat.id)",
            contentType: "application/octet-stream"
        )
    }
    
    private func uploadAudio(_ url: URL, messageId: String) async throws -> String {
        let data = try Data(contentsOf: url)
        let fileName = "\(messageId).m4a"
        return try await SupabaseStorageService.shared.uploadFile(
            data,
            fileName: fileName,
            folder: "chat_audio/\(chat.id)",
            contentType: "audio/mp4"
        )
    }
    
    deinit {
        stopListening()
    }
}
