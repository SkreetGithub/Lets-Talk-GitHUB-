import SwiftUI
import Foundation

struct DynamicIslandViews: View {
    @StateObject private var notificationManager = NotificationManager.shared
    private let webRTCService = WebRTCService()
    
    var body: some View {
        ZStack {
            if let message = notificationManager.currentMessage {
                MessageIslandView(
                    message: message.0,
                    sender: message.1,
                    profileImage: message.2
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if let call = notificationManager.currentCall {
                CallIslandView(
                    caller: call.callerName,
                    isVideoCall: call.isVideoCall,
                    callerImage: call.callerImage,
                    onAccept: {
                        // webRTCService.acceptCall() // TODO: Implement acceptCall method
                    },
                    onDecline: {
                        // webRTCService.rejectCall() // TODO: Implement rejectCall method
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: notificationManager.currentMessage?.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: notificationManager.currentCall)
    }
}

struct MessageIslandView: View {
    let message: String
    let sender: String
    let profileImage: String?
    @State private var isExpanded = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            if let imageUrl = profileImage {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(sender.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.white)
                        )
                }
            } else {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(sender.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }
            
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
                if let imageUrl = callerImage {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.green, .blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(caller.prefix(1).uppercased())
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.green, .blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(caller.prefix(1).uppercased())
                                .font(.title2)
                                .foregroundColor(.white)
                        )
                }
                
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
