import SwiftUI

struct EnhancedMessageView: View {
    var contact: Contact
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var messageText: String = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(content: "Hey there! How are you doing today?", isOutgoing: true, timestamp: Date().addingTimeInterval(-3600)),
        ChatMessage(content: "Hi! I'm doing great, thanks for asking! How about you?", isOutgoing: false, timestamp: Date().addingTimeInterval(-3500)),
        ChatMessage(content: "I'm good too! Just working on some exciting projects.", isOutgoing: true, timestamp: Date().addingTimeInterval(-3400)),
        ChatMessage(content: "That sounds amazing! I'd love to hear more about it sometime.", isOutgoing: false, timestamp: Date().addingTimeInterval(-3300))
    ]
    @StateObject private var translationManager = SimpleTranslationManager()
    @State private var translatedMessages: [ChatMessage] = []
    @State private var isTyping = false
    @State private var showEmojiPicker = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
            messagesView
            inputView
        }
        .navigationBarHidden(true)
        .background(backgroundView)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Contact Info
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 50, height: 50)
                        
                        Text(contact.initials)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            
                            Text("Online")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button(action: {
                        // Video call action
                    }) {
                        Image(systemName: "video.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        // Voice call action
                    }) {
                        Image(systemName: "phone.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                    
                    Button(action: {
                        // More options
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Translation Toggle
            HStack {
                Text("Live Translation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Toggle("", isOn: .constant(false))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator))
                .offset(y: 0.25),
            alignment: .bottom
        )
    }
    
    // MARK: - Messages View
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubbleView(
                            message: message,
                            isTranslated: translatedMessages.contains { $0.id == message.id },
                            onTranslate: { message in
                                translateMessage(message)
                            }
                        )
                        .id(message.id)
                    }
                    
                    if isTyping {
                        TypingIndicatorView()
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    // MARK: - Input View
    private var inputView: some View {
        VStack(spacing: 0) {
            if showEmojiPicker {
                EmojiPickerView(selectedEmoji: $messageText)
                    .frame(height: 200)
                    .background(Color(.systemGray6))
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    showEmojiPicker.toggle()
                }) {
                    Image(systemName: "face.smiling")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        Group {
            if settingsManager.settings.theme.isGradient {
                LinearGradient(
                    gradient: Gradient(colors: settingsManager.settings.theme.gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                settingsManager.settings.theme.gradientColors.first ?? Color.primary
            }
        }
    }
    
    // MARK: - Helper Methods
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newMessage = ChatMessage(
            content: messageText,
            isOutgoing: true,
            timestamp: Date()
        )
        
        messages.append(newMessage)
        messageText = ""
        
        // Simulate typing indicator
        isTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isTyping = false
            let response = ChatMessage(
                content: "Thanks for your message! I'll get back to you soon.",
                isOutgoing: false,
                timestamp: Date()
            )
            messages.append(response)
        }
    }
    
    private func translateMessage(_ message: ChatMessage) {
        translationManager.translate(text: message.content, from: "en", to: "es") { translatedText in
            let translatedMessage = ChatMessage(
                content: translatedText,
                isOutgoing: message.isOutgoing,
                timestamp: message.timestamp
            )
            
            if let index = translatedMessages.firstIndex(where: { $0.id == message.id }) {
                translatedMessages[index] = translatedMessage
            } else {
                translatedMessages.append(translatedMessage)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation(.easeInOut(duration: 0.5)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    let isTranslated: Bool
    let onTranslate: (ChatMessage) -> Void
    
    var body: some View {
        HStack {
            if message.isOutgoing {
                Spacer()
                messageContent
            } else {
                messageContent
                Spacer()
            }
        }
    }
    
    private var messageContent: some View {
        VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(message.isOutgoing ? Color.blue : Color(.systemGray5))
                )
                .foregroundColor(message.isOutgoing ? .white : .primary)
            
            HStack(spacing: 8) {
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if !isTranslated {
                    Button("Translate") {
                        onTranslate(message)
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - Typing Indicator View
struct TypingIndicatorView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffset)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animationOffset
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5))
            )
            
            Spacer()
        }
        .onAppear {
            animationOffset = -4
        }
    }
}

// MARK: - Emoji Picker View
struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    
    private let emojis = ["😀", "😂", "😍", "🥰", "😎", "🤔", "😢", "😡", "👍", "👎", "❤️", "🔥", "💯", "🎉", "🚀"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: {
                        selectedEmoji += emoji
                    }) {
                        Text(emoji)
                            .font(.title)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let content: String
    let isOutgoing: Bool
    let timestamp: Date
}

// MARK: - Simple Translation Manager
class SimpleTranslationManager: ObservableObject {
    func translate(text: String, from: String, to: String, completion: @escaping (String) -> Void) {
        // Simulate translation delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion("[Translated] \(text)")
        }
    }
}

// MARK: - Contact Extension (removed to avoid duplicate declaration)

#Preview {
    EnhancedMessageView(contact: Contact(
        name: "John Doe",
        phone: "123-456-7890",
        email: "john@example.com",
        lastMessage: "Hello!",
        image: nil
    ))
    .environmentObject(SettingsManager.shared)
}