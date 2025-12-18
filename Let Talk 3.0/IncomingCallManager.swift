import Foundation
import SwiftUI
import AVFoundation
import UserNotifications

// MARK: - Incoming Call Manager
class IncomingCallManager: ObservableObject {
    static let shared = IncomingCallManager()
    
    @Published var isShowingIncomingCall = false
    @Published var currentIncomingCall: Call?
    
    private var audioPlayer: AVAudioPlayer?
    private var callTimer: Timer?
    private var ringtoneTimer: Timer?
    
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error setting up audio session: \(error)")
        }
    }
    
    // MARK: - Incoming Call Handling
    
    func showIncomingCall(from callerId: String, isVideo: Bool) {
        // Create incoming call object
        let call = Call(
            id: UUID().uuidString,
            callerId: callerId,
            calleeId: AuthManager.shared.currentUserId ?? "",
            isVideo: isVideo,
            status: .initiated,
            createdAt: Date(),
            participants: [callerId, AuthManager.shared.currentUserId ?? ""].filter { !$0.isEmpty }
        )
        
        DispatchQueue.main.async {
            self.currentIncomingCall = call
            self.isShowingIncomingCall = true
        }
        
        // Start ringing
        startRinging()
        
        // Send local notification
        sendLocalNotification(for: call)
        
        // Auto-reject after 30 seconds
        startCallTimer()
    }
    
    func answerIncomingCall() {
        stopRinging()
        stopCallTimer()
        
        DispatchQueue.main.async {
            self.isShowingIncomingCall = false
        }
        
        // The actual call answering is handled by the CallInterfaceView
    }
    
    func rejectIncomingCall() {
        stopRinging()
        stopCallTimer()
        
        // Reject call in Supabase-backed signaling
        if let call = currentIncomingCall {
            Task {
                try? await FirebaseSignalingService.shared.rejectCall(callId: call.id)
            }
        }
        
        DispatchQueue.main.async {
            self.isShowingIncomingCall = false
            self.currentIncomingCall = nil
        }
    }
    
    func dismissIncomingCall() {
        stopRinging()
        stopCallTimer()
        
        DispatchQueue.main.async {
            self.isShowingIncomingCall = false
            self.currentIncomingCall = nil
        }
    }
    
    // MARK: - Ringing
    
    private func startRinging() {
        // Play system ringtone
        playRingtone()
        
        // Vibrate device
        vibrateDevice()
    }
    
    private func stopRinging() {
        audioPlayer?.stop()
        audioPlayer = nil
        ringtoneTimer?.invalidate()
        ringtoneTimer = nil
    }
    
    private func playRingtone() {
        // Use system ringtone
        let systemSoundID: SystemSoundID = 1000 // Default ringtone
        AudioServicesPlaySystemSound(systemSoundID)
        
        // Repeat every 3 seconds
        ringtoneTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            AudioServicesPlaySystemSound(systemSoundID)
        }
    }
    
    private func vibrateDevice() {
        // Vibrate device
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    // MARK: - Call Timer
    
    private func startCallTimer() {
        callTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            self.autoRejectCall()
        }
    }
    
    private func stopCallTimer() {
        callTimer?.invalidate()
        callTimer = nil
    }
    
    private func autoRejectCall() {
        // Auto-reject call after 30 seconds
        rejectIncomingCall()
    }
    
    // MARK: - Local Notifications
    
    private func sendLocalNotification(for call: Call) {
        let content = UNMutableNotificationContent()
        content.title = "Incoming Call"
        content.body = "Call from \(call.callerId)"
        content.sound = .default
        content.categoryIdentifier = "INCOMING_CALL"
        
        // Add call actions
        let answerAction = UNNotificationAction(
            identifier: "ANSWER_CALL",
            title: "Answer",
            options: [.foreground]
        )
        
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_CALL",
            title: "Decline",
            options: []
        )
        
        let callCategory = UNNotificationCategory(
            identifier: "INCOMING_CALL",
            actions: [answerAction, declineAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([callCategory])
        
        let request = UNNotificationRequest(
            identifier: call.id,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            }
        }
    }
}

// MARK: - Incoming Call View

struct IncomingCallView: View {
    @StateObject private var callManager = IncomingCallManager.shared
    @StateObject private var webrtcManager = WebRTCCallManager.shared
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showCallInterface = false
    
    var body: some View {
        ZStack {
            if callManager.isShowingIncomingCall, let call = callManager.currentIncomingCall {
                // Incoming call overlay
                incomingCallOverlay(call: call)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            
            if showCallInterface, let call = callManager.currentIncomingCall {
                // Call interface
                CallInterfaceView(call: call, isIncoming: true)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .onChange(of: callManager.isShowingIncomingCall) { isShowing in
            if !isShowing {
                showCallInterface = false
            }
        }
    }
    
    private func incomingCallOverlay(call: Call) -> some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss on tap outside
                }
            
            VStack(spacing: 30) {
                // Caller info
                VStack(spacing: 16) {
                    // Avatar
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text(String(call.callerId.prefix(1)).uppercased())
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    // Caller name
                    Text(call.callerId)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    // Call type
                    Text(call.isVideo ? "Video Call" : "Voice Call")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Action buttons
                HStack(spacing: 60) {
                    // Decline button
                    Button(action: {
                        withAnimation {
                            callManager.rejectIncomingCall()
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Color.red)
                                .clipShape(Circle())
                            
                            Text("Decline")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Answer button
                    Button(action: {
                        withAnimation {
                            callManager.answerIncomingCall()
                            showCallInterface = true
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Color.green)
                                .clipShape(Circle())
                            
                            Text("Answer")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Call Overlay

struct IncomingCallOverlay: View {
    @StateObject private var callManager = IncomingCallManager.shared
    
    var body: some View {
        if callManager.isShowingIncomingCall {
            IncomingCallView()
                .zIndex(1000)
        }
    }
}

struct IncomingCallManager_Previews: PreviewProvider {
    static var previews: some View {
        IncomingCallView()
            .environmentObject(AuthManager.shared)
    }
}
