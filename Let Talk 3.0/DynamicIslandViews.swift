import SwiftUI
import Foundation

struct DynamicIslandViews: View {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        ZStack {
            if let message = notificationManager.currentMessage {
                MessageIslandView(
                    message: message.text,
                    sender: message.senderName,
                    senderId: message.senderId,
                    profileImage: message.photo
                )
                .onTapGesture {
                    // Tapping the banner opens that conversation.
                    if let chatId = message.chatId { notificationManager.pendingChatId = chatId }
                    notificationManager.dismissMessageBanner()
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if let call = notificationManager.currentCall {
                CallIslandView(
                    caller: call.callerName,
                    isVideoCall: call.isVideoCall,
                    callerImage: call.callerImage,
                    onAccept: {
                        IncomingCallManager.shared.answerIncomingCall()
                        if let incoming = IncomingCallManager.shared.currentIncomingCall {
                            Task {
                                try? await WebRTCCallManager.shared.answerCall(callId: incoming.id, isVideo: incoming.isVideo)
                            }
                        }
                        notificationManager.currentCall = nil
                    },
                    onDecline: {
                        IncomingCallManager.shared.rejectIncomingCall()
                        notificationManager.currentCall = nil
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: notificationManager.currentMessage)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: notificationManager.currentCall)
    }
}

struct MessageIslandView: View {
    let message: String
    let sender: String
    var senderId: String? = nil
    let profileImage: String?
    @State private var isExpanded = false
    
    var body: some View {
        HStack(spacing: 12) {
            // The sender's photo (private photos and initials handled by ProfileImageView)
            UserAvatar(userId: senderId, name: sender, fallbackURL: profileImage, size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(sender)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(isExpanded ? nil : 1)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
}

struct CallIslandView: View {
    let caller: String
    let isVideoCall: Bool
    let callerImage: String?
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Caller Image with pulsing effect
            ZStack {
                ProfileImageView(imageURL: callerImage, placeholderText: Initials.from(caller), size: 50)
                
                // Pulsing ring
                Circle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0.0 : 1.0)
                    .animation(
                        Animation.easeOut(duration: 1.0)
                            .repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            }
            .onAppear {
                isPulsing = true
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(caller)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: isVideoCall ? "video.fill" : "phone.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(isVideoCall ? "Video Call" : "Voice Call")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // Decline button
                Button(action: onDecline) {
                    Image(systemName: "phone.down.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.red)
                                .shadow(color: .red.opacity(0.3), radius: 5, x: 0, y: 2)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                
                // Accept button
                Button(action: onAccept) {
                    Image(systemName: isVideoCall ? "video.fill" : "phone.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.green)
                                .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 2)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
        )
        .padding(.horizontal)
    }
}

// MARK: - Button Style (using existing ScaleButtonStyle from TranslatorView)

#Preview {
    DynamicIslandViews()
}
