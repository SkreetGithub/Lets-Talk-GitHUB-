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
    @Published var contact: Contact
    
    private let chat: Chat
    private let databaseManager = DatabaseManager.shared
    private let webRTCService = WebRTCService()
    private var cancellables = Set<AnyCancellable>()
    private var audioRecorder: AVAudioRecorder?
    private var audioRecordingURL: URL?
    
    var messageGroups: [Date: [Message]] {
        Dictionary(grouping: messages) { message in
            Calendar.current.startOfDay(for: message.timestamp)
        }
    }
    
    init(chat: Chat) {
        self.chat = chat
        self.contact = Contact(name: "", phone: "", email: "") // Placeholder
        loadContact()
    }
    
    private func loadContact() {
        guard let contactId = chat.participants.first(where: { $0 != AuthManager.shared.currentUserId }) else { return }
        
        Task {
            do {
                let contact = try await databaseManager.getUser(id: contactId)
                await MainActor.run {
                    self.contact = Contact(
                        id: contactId, // FIXED: Set the contact ID
                        name: contact.name,
                        phone: contact.phone,
                        email: contact.email,
                        lastMessage: nil,
                        image: nil
                    )
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
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
                self?.messages = messages.sorted { $0.timestamp < $1.timestamp }
                self?.markMessagesAsRead(messages)
            }
            .store(in: &cancellables)
    }
    
    func stopListening() {
        cancellables.removeAll()
    }
    
    private func markMessagesAsRead(_ messages: [Message]) {
        let unreadMessages = messages.filter { message in
            message.senderId != AuthManager.shared.currentUserId &&
            message.status != .read
        }
        
        guard !unreadMessages.isEmpty else { return }
        
        Task {
            do {
                try await databaseManager.markMessagesAsRead(unreadMessages.map { $0.id })
            } catch {
                self.error = error
            }
        }
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        guard let currentUserId = AuthManager.shared.currentUserId, !currentUserId.isEmpty else {
            print("Error: User not authenticated")
            return
        }
        
        guard !contact.id.isEmpty else {
            print("Error: Contact ID is empty")
            return
        }
        
        print("Sending message from \(currentUserId) to \(contact.id): \(messageText)")
        
        let message = Message(
            senderId: currentUserId,
            receiverId: contact.id,
            content: messageText,
            type: .text
        )
        
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
                    receiverId: contact.id,
                    content: "Sent an image",
                    type: .image,
                    attachments: [attachment]
                )
                
                send(message)
                selectedImage = nil
            } catch {
                self.error = error
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
                    receiverId: contact.id,
                    content: "Sent a document",
                    type: .file,
                    attachments: [attachment]
                )
                
                send(message)
                selectedDocument = nil
            } catch {
                self.error = error
            }
        }
    }
    
    func sendLocation() {
        guard let location = selectedLocation else { return }
        
        let message = Message(
            senderId: AuthManager.shared.currentUserId ?? "",
            receiverId: contact.id,
            content: "\(location.latitude),\(location.longitude)",
            type: .location
        )
        
        send(message)
        selectedLocation = nil
    }
    
    func sendContact() {
        guard let contact = selectedContact else { return }
        
        guard let contactData = try? JSONEncoder().encode(contact),
              let contactString = String(data: contactData, encoding: .utf8) else {
            return
        }
        
        let message = Message(
            senderId: AuthManager.shared.currentUserId ?? "",
            receiverId: contact.id,
            content: contactString,
            type: .contact
        )
        
        send(message)
        selectedContact = nil
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
            self.error = error
            isRecording = false
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        guard let url = audioRecordingURL else { return }
        
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
                    receiverId: contact.id,
                    content: "Sent a voice message",
                    type: .audio,
                    attachments: [attachment]
                )
                
                send(message)
                audioRecordingURL = nil
            } catch {
                self.error = error
            }
        }
    }
    
    private func send(_ message: Message) {
        Task {
            do {
                try await databaseManager.sendMessage(message)
            } catch {
                self.error = error
            }
        }
    }
    
    func startAudioCall() {
        Task {
            do {
                try await webRTCService.startCall(to: contact.phone)
            } catch {
                self.error = error
            }
        }
    }
    
    func startVideoCall() {
        Task {
            do {
                try await webRTCService.startVideoCall(to: contact.phone)
            } catch {
                self.error = error
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
