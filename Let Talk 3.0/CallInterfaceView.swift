import SwiftUI
import WebRTC
import AVFoundation

struct CallInterfaceView: View {
    @StateObject private var callManager = WebRTCCallManager.shared
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var localVideoView = RTCMTLVideoView()
    @State private var remoteVideoView = RTCMTLVideoView()
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var callDuration: TimeInterval = 0
    @State private var callTimer: Timer?
    
    let call: Call
    let isIncoming: Bool
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Video Views
            videoViews
            
            // Call Info Overlay
            callInfoOverlay
            
            // Controls Overlay
            if showControls {
                controlsOverlay
            }
            
            // Status Overlay
            statusOverlay
        }
        .onAppear {
            setupCall()
            startControlsTimer()
            startCallTimer()
        }
        .onDisappear {
            stopTimers()
        }
        .onTapGesture {
            toggleControls()
        }
        .onChange(of: callManager.callStatus) { oldValue, status in
            handleCallStatusChange(status)
        }
    }
    
    // MARK: - Video Views
    
    private var videoViews: some View {
        ZStack {
            // Remote video (full screen)
            if callManager.isInCall && callManager.connectionState == .connected {
                RemoteVideoView(remoteVideoView: $remoteVideoView)
                    .ignoresSafeArea()
            } else {
                // Placeholder when no video
                Color.black.ignoresSafeArea()
            }
            
            // Local video (picture-in-picture)
            if call.isVideo && callManager.isVideoEnabled {
                LocalVideoView(localVideoView: $localVideoView)
                    .frame(width: 120, height: 160)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .position(x: UIScreen.main.bounds.width - 80, y: 100)
            }
        }
    }
    
    // MARK: - Call Info Overlay
    
    private var callInfoOverlay: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(call.calleeId == authManager.currentUserId ? call.callerId : call.calleeId)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(call.isVideo ? "Video Call" : "Voice Call")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if callManager.callStatus == .connected {
                        Text(formatDuration(callDuration))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Connection status indicator
                connectionStatusIndicator
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            Spacer()
        }
    }
    
    // MARK: - Controls Overlay
    
    private var controlsOverlay: some View {
        VStack {
            Spacer()
            
            // Call controls
            HStack(spacing: 40) {
                // Mute button
                CallControlButton(
                    icon: callManager.isAudioEnabled ? "mic.fill" : "mic.slash.fill",
                    color: .white,
                    backgroundColor: callManager.isAudioEnabled ? .white.opacity(0.2) : .red,
                    action: { callManager.toggleAudio() }
                )
                
                // Video button (only for video calls)
                if call.isVideo {
                    CallControlButton(
                        icon: callManager.isVideoEnabled ? "video.fill" : "video.slash.fill",
                        color: .white,
                        backgroundColor: callManager.isVideoEnabled ? .white.opacity(0.2) : .red,
                        action: { callManager.toggleVideo() }
                    )
                }
                
                // Speaker button
                CallControlButton(
                    icon: callManager.isSpeakerEnabled ? "speaker.wave.3.fill" : "speaker.fill",
                    color: .white,
                    backgroundColor: callManager.isSpeakerEnabled ? .blue : .white.opacity(0.2),
                    action: { callManager.toggleSpeaker() }
                )
                
                // Camera switch (only for video calls)
                if call.isVideo {
                    CallControlButton(
                        icon: "camera.rotate.fill",
                        color: .white,
                        backgroundColor: .white.opacity(0.2),
                        action: { callManager.switchCamera() }
                    )
                }
            }
            .padding(.bottom, 40)
            
            // Main action button
            HStack(spacing: 60) {
                if isIncoming && callManager.callStatus == .incoming {
                    // Answer button
                    CallControlButton(
                        icon: "phone.fill",
                        color: .white,
                        backgroundColor: .green,
                        size: 80,
                        action: { answerCall() }
                    )
                    
                    // Decline button
                    CallControlButton(
                        icon: "phone.down.fill",
                        color: .white,
                        backgroundColor: .red,
                        size: 80,
                        action: { declineCall() }
                    )
                } else {
                    // End call button
                    CallControlButton(
                        icon: "phone.down.fill",
                        color: .white,
                        backgroundColor: .red,
                        size: 80,
                        action: { endCall() }
                    )
                }
            }
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Status Overlay
    
    private var statusOverlay: some View {
        VStack {
            if callManager.callStatus != .connected && callManager.callStatus != .idle {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    
                    Text(statusText)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
            }
            
            Spacer()
        }
        .padding(.top, 200)
    }
    
    // MARK: - Connection Status Indicator
    
    private var connectionStatusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
            
            Text(connectionStatusText)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        switch callManager.callStatus {
        case .incoming:
            return "Incoming Call"
        case .initiating:
            return "Calling..."
        case .answering:
            return "Answering..."
        case .connecting:
            return "Connecting..."
        case .connected:
            return ""
        case .disconnected:
            return "Disconnected"
        case .failed:
            return "Call Failed"
        case .ending:
            return "Ending Call..."
        default:
            return ""
        }
    }
    
    private var connectionStatusColor: Color {
        switch callManager.connectionState {
        case .connected, .completed:
            return .green
        case .checking:
            return .yellow
        case .disconnected, .failed, .closed:
            return .red
        default:
            return .gray
        }
    }
    
    private var connectionStatusText: String {
        switch callManager.connectionState {
        case .connected, .completed:
            return "Connected"
        case .checking:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        case .failed:
            return "Failed"
        case .closed:
            return "Closed"
        default:
            return "Connecting"
        }
    }
    
    // MARK: - Methods
    
    private func setupCall() {
        // Set up video views
        callManager.setLocalVideoView(localVideoView)
        callManager.setRemoteVideoView(remoteVideoView)
    }
    
    private func answerCall() {
        Task {
            try? await callManager.answerCall(callId: call.id, isVideo: call.isVideo)
        }
    }
    
    private func declineCall() {
        Task {
            await callManager.rejectCall()
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func endCall() {
        Task {
            await callManager.endCall()
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls.toggle()
        }
        
        if showControls {
            startControlsTimer()
        } else {
            stopControlsTimer()
        }
    }
    
    private func startControlsTimer() {
        stopControlsTimer()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
    
    private func stopControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = nil
    }
    
    private func startCallTimer() {
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if callManager.callStatus == .connected {
                callDuration += 1
            }
        }
    }
    
    private func stopTimers() {
        stopControlsTimer()
        callTimer?.invalidate()
        callTimer = nil
    }
    
    private func handleCallStatusChange(_ status: WebRTCCallStatus) {
        switch status {
        case .ended, .failed:
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                presentationMode.wrappedValue.dismiss()
            }
        default:
            break
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Call Control Button

// Note: CallControlButton is defined in CallView.swift

// MARK: - Video Views

struct LocalVideoView: UIViewRepresentable {
    @Binding var localVideoView: RTCMTLVideoView
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        localVideoView.videoContentMode = .scaleAspectFill
        return localVideoView
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // Update if needed
    }
}

struct RemoteVideoView: UIViewRepresentable {
    @Binding var remoteVideoView: RTCMTLVideoView
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        remoteVideoView.videoContentMode = .scaleAspectFill
        return remoteVideoView
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // Update if needed
    }
}

struct CallInterfaceView_Previews: PreviewProvider {
    static var previews: some View {
        CallInterfaceView(
            call: Call(
                id: "test",
                callerId: "user1",
                calleeId: "user2",
                isVideo: true,
                status: .initiated,
                createdAt: Date(),
                participants: ["user1", "user2"]
            ),
            isIncoming: false
        )
        .environmentObject(AuthManager.shared)
    }
}
