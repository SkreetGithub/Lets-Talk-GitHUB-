import SwiftUI
import AVFoundation
import CoreLocation

struct ChatDetailView: View {
    let chat: Chat
    @StateObject private var viewModel: ChatDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showAttachmentPicker = false
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var showLocationPicker = false
    @State private var showContactPicker = false
    @State private var showTranslation = false
    @State private var messageToTranslate: Message?
    @State private var scrollToBottom = false
    
    init(chat: Chat) {
        self.chat = chat
        _viewModel = StateObject(wrappedValue: ChatDetailViewModel(chat: chat))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            messagesList
            messageInputBar
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .sheet(isPresented: $showTranslation) {
            if let message = messageToTranslate {
                TranslationView(message: message)
            }
        }
        .actionSheet(isPresented: $showAttachmentPicker) {
            ActionSheet(title: Text("Add Attachment"), buttons: [
                .default(Text("Photo/Video")) { showImagePicker = true },
                .default(Text("Document")) { showDocumentPicker = true },
                .default(Text("Location")) { showLocationPicker = true },
                .default(Text("Contact")) { showContactPicker = true },
                .cancel()
            ])
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $viewModel.selectedImage)
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { url in
                viewModel.selectedDocument = url
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPicker(selectedLocation: $viewModel.selectedLocation)
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPicker(selectedContact: $viewModel.selectedContact)
        }
    }
    
    // MARK: - Computed Properties
    
    private var chatHeader: some View {
        ChatHeader(
            contact: viewModel.contact,
            onAudioCall: viewModel.startAudioCall,
            onVideoCall: viewModel.startVideoCall,
            onBack: { presentationMode.wrappedValue.dismiss() }
        )
    }
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.messageGroups.keys.sorted(), id: \.self) { date in
                        Section(header: DateHeader(date: date)) {
                            ForEach(viewModel.messageGroups[date] ?? []) { message in
                                MessageBubble(
                                    message: message,
                                    showTranslation: $showTranslation,
                                    messageToTranslate: $messageToTranslate
                                )
                                .id(message.id)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)
            }
            .onChange(of: viewModel.messages) { oldValue, newValue in
                if scrollToBottom {
                    withAnimation {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                    scrollToBottom = false
                }
            }
        }
    }
    
    private var messageInputBar: some View {
        MessageInputBar(
            text: $viewModel.messageText,
            isRecording: $viewModel.isRecording,
            onSend: {
                viewModel.sendMessage()
                scrollToBottom = true
            },
            onAttachment: { showAttachmentPicker = true }
        )
    }
}

struct ChatHeader: View {
    let contact: Contact
    let onAudioCall: () -> Void
    let onVideoCall: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
            }
            
            ProfileImageView(imageURL: contact.imageURL,
                           placeholderText: contact.initials)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.headline)
                
                if contact.isOnline {
                    Text("Online")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if let lastSeen = contact.lastSeen {
                    Text("Last seen \(timeAgo(from: lastSeen))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button(action: onAudioCall) {
                Image(systemName: "phone")
                    .font(.system(size: 20))
            }
            
            Button(action: onVideoCall) {
                Image(systemName: "video")
                    .font(.system(size: 20))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct MessageBubble: View {
    let message: Message
    @Binding var showTranslation: Bool
    @Binding var messageToTranslate: Message?
    
    var body: some View {
        HStack {
            if message.isOutgoing {
                Spacer()
            }
            
            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                switch message.type {
                case .text:
                    textContent
                case .image:
                    imageContent
                case .video:
                    videoContent
                case .audio:
                    audioContent
                case .file:
                    fileContent
                case .location:
                    locationContent
                case .contact:
                    contactContent
                case .system:
                    systemContent
                }
                
                HStack(spacing: 4) {
                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    if message.isOutgoing {
                        Image(systemName: statusIcon)
                            .font(.caption2)
                            .foregroundColor(message.status == .failed ? .red : .blue)
                    }
                }
            }
            .padding(10)
            .background(bubbleBackground)
            .cornerRadius(16)
            .contextMenu {
                messageContextMenu
            }
            
            if !message.isOutgoing {
                Spacer()
            }
        }
    }
    
    private var textContent: some View {
        Text(message.content)
            .foregroundColor(message.isOutgoing ? .white : .primary)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var imageContent: some View {
        Group {
            if let url = message.attachments?.first?.url {
                AsyncImage(url: URL(string: url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 200, maxHeight: 200)
                        .cornerRadius(8)
                } placeholder: {
                    ProgressView()
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private var videoContent: some View {
        Group {
            if let url = message.attachments?.first?.url {
                VideoThumbnail(url: URL(string: url)!)
                    .frame(width: 200, height: 150)
                    .cornerRadius(8)
            } else {
                EmptyView()
            }
        }
    }
    
    private var audioContent: some View {
        Group {
            if let url = message.attachments?.first?.url {
                AudioPlayer(url: URL(string: url)!)
                    .frame(width: 200, height: 50)
            } else {
                EmptyView()
            }
        }
    }
    
    private var fileContent: some View {
        Group {
            if let attachment = message.attachments?.first {
                HStack {
                    Image(systemName: "doc")
                    VStack(alignment: .leading) {
                        Text(attachment.name)
                            .lineLimit(1)
                        Text(formatFileSize(attachment.size))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private var locationContent: some View {
        Group {
            let components = message.content.split(separator: ",")
            if components.count == 2,
               let latitude = Double(components[0]),
               let longitude = Double(components[1]) {
                MapThumbnail(latitude: latitude, longitude: longitude)
                    .frame(width: 200, height: 150)
                    .cornerRadius(8)
            } else {
                EmptyView()
            }
        }
    }
    
    private var contactContent: some View {
        Group {
            if let contact = try? JSONDecoder().decode(Contact.self, from: message.content.data(using: .utf8)!) {
                HStack {
                    Image(systemName: "person.circle")
                    VStack(alignment: .leading) {
                        Text(contact.name)
                        Text(contact.phone)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private var systemContent: some View {
        Text(message.content)
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
    
    private var bubbleBackground: some View {
        Group {
            if message.isOutgoing {
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(.systemGray6)
            }
        }
    }
    
    private var statusIcon: String {
        switch message.status {
        case .sending:
            return "clock"
        case .sent:
            return "checkmark"
        case .delivered:
            return "checkmark.circle"
        case .read:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle"
        }
    }
    
    private var messageContextMenu: some View {
        Group {
            if message.type == .text {
                Button(action: {
                    UIPasteboard.general.string = message.content
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                
                Button(action: {
                    messageToTranslate = message
                    showTranslation = true
                }) {
                    Label("Translate", systemImage: "text.bubble")
                }
            }
            
            if message.isOutgoing && message.status == .failed {
                Button(action: {
                    // Implement retry logic
                }) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
            }
            
            Button(role: .destructive, action: {
                // Implement delete logic
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

struct MessageInputBar: View {
    @Binding var text: String
    @Binding var isRecording: Bool
    let onSend: () -> Void
    let onAttachment: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onAttachment) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            
            if isRecording {
                recordingView
            } else {
                textInputView
            }
            
            Button(action: {
                if text.isEmpty {
                    isRecording.toggle()
                } else {
                    onSend()
                }
            }) {
                Image(systemName: text.isEmpty ? (isRecording ? "stop.circle.fill" : "mic.circle.fill") : "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isRecording ? .red : .blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
    
    private var textInputView: some View {
        TextField("Message", text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
    }
    
    private var recordingView: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundColor(.red)
            Text("Recording...")
                .foregroundColor(.red)
            Spacer()
        }
        .padding(.horizontal)
        .frame(height: 36)
        .background(Color(.systemGray6))
        .cornerRadius(18)
    }
}

struct DateHeader: View {
    let date: Date
    
    var body: some View {
        Text(formatDate(date))
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Missing Components
struct TranslationView: View {
    let message: Message
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = TranslationViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Original: \(message.content)")
                    .padding()
                
                if viewModel.isTranslating {
                    ProgressView()
                } else {
                    Text("Translation: \(viewModel.translatedText)")
                        .padding()
                }
            }
            .navigationTitle("Translation")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            viewModel.translate(text: message.content)
        }
    }
}

class TranslationViewModel: ObservableObject {
    @Published var translatedText = ""
    @Published var isTranslating = false
    
    func translate(text: String) {
        isTranslating = true
        // Implement translation logic
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            self.translatedText = "Translated: \(text)"
            self.isTranslating = false
        }
    }
}

// MARK: - ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Note: DocumentPicker is defined in OfflineIndicatorView.swift

struct LocationPicker: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Location Picker")
                // Implement location picker
            }
            .navigationTitle("Select Location")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct ContactPicker: View {
    @Binding var selectedContact: Contact?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Contact Picker")
                // Implement contact picker
            }
            .navigationTitle("Select Contact")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct VideoThumbnail: View {
    let url: URL
    
    var body: some View {
        VStack {
            Image(systemName: "video.fill")
                .font(.system(size: 40))
            Text("Video")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.3))
    }
}

struct AudioPlayer: View {
    let url: URL
    
    var body: some View {
        HStack {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 30))
            Text("Audio Message")
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }
}

struct MapThumbnail: View {
    let latitude: Double
    let longitude: Double
    
    var body: some View {
        VStack {
            Image(systemName: "map.fill")
                .font(.system(size: 40))
            Text("Location")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.3))
    }
}


struct ChatDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleChat = Chat(
            id: "1",
            participants: ["user1", "user2"],
            lastMessage: Chat.LastMessage(
                content: "Hello",
                senderId: "user1",
                timestamp: Date(),
                type: .text
            ),
            createdAt: Date(),
            lastUpdated: Date()
        )
        
        ChatDetailView(chat: sampleChat)
    }
}
