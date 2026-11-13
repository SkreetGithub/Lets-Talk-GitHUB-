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
    @StateObject private var liveTranslation = LiveTranslationSession.shared
    @State private var otherPartyName: String?
    // The consent prompt must be shown from the call screen: it sits in its own window above the
    // app, so the app-level consent sheet opened invisibly behind it and translation never started.
    @ObservedObject private var consent = AIConsent.shared
    
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

            // Subtitles + controls share one bottom stack so they can never overlap.
            // The end-call / answer / decline row is always visible; secondary controls auto-hide.
            controlsOverlay
            
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
            liveTranslation.stop()
        }
        .task {
            // Show the other person's name, not their raw user ID.
            otherPartyName = try? await DatabaseManager.shared.getUser(id: otherPartyId).name
        }
        .onTapGesture {
            toggleControls()
        }
        .sheet(isPresented: $consent.needsPrompt) {
            AIConsentView()
        }
        .onChange(of: consent.hasConsented) { _, granted in
            // Start translating as soon as the user agrees mid-call.
            if granted && callManager.callStatus == .connected { liveTranslation.start() }
        }
        .onChange(of: callManager.callStatus) { _, status in
            if status == .connected {
                liveTranslation.start()
            } else if status == .ending || status == .idle {
                liveTranslation.stop()
            }
            handleCallStatusChange(status)
        }
    }
    
    // MARK: - Video Views
    
    private var videoViews: some View {
        ZStack {
            // Remote video (full screen)
            if callManager.isInCall && (callManager.connectionState == .connected || callManager.connectionState == .completed) {
                RemoteVideoView(remoteVideoView: $remoteVideoView)
                    .ignoresSafeArea()
            } else {
                // Placeholder when no video
                Color.black.ignoresSafeArea()
            }
            
            // Local video (picture-in-picture)
            if call.isVideo && callManager.isVideoEnabled {
                // Anchored top-right BELOW the name/status row (it used to sit on top of the
                // connection indicator and translation chip at a fixed screen position).
                LocalVideoView(localVideoView: $localVideoView)
                    .frame(width: 110, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadiusS, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadiusS, style: .continuous)
                            .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 110)
                    .padding(.trailing, DS.spacingM)
                    .accessibilityLabel("Your camera preview")
            }
        }
    }
    
    // MARK: - Call Info Overlay
    
    private var callInfoOverlay: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(otherPartyName ?? "Let Talk user")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
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
                
                VStack(alignment: .trailing, spacing: 8) {
                    // Connection status indicator
                    connectionStatusIndicator
                    LiveTranslationChip(session: liveTranslation)
                }
            }
            .padding(.horizontal, DS.spacingL)
            .padding(.top, DS.spacingM)          // safe area already clears the Dynamic Island
            
            Spacer()
        }
    }
    
    // MARK: - Controls Overlay
    
    private var controlsOverlay: some View {
        VStack(spacing: DS.spacingL) {
            Spacer()
            
            // Live translation subtitles sit directly above the controls
            SubtitleOverlay(session: liveTranslation)
            
            // Secondary controls (auto-hide)
            if showControls {
                HStack(spacing: 0) {
                    CallControlButton(
                        icon: callManager.isAudioEnabled ? "mic.fill" : "mic.slash.fill",
                        color: .white,
                        backgroundColor: callManager.isAudioEnabled ? .white.opacity(0.2) : .red,
                        action: { callManager.toggleAudio() }
                    )
                    .frame(maxWidth: .infinity)   // equal share of the row: evenly spaced
                    
                    if call.isVideo {
                        CallControlButton(
                            icon: callManager.isVideoEnabled ? "video.fill" : "video.slash.fill",
                            color: .white,
                            backgroundColor: callManager.isVideoEnabled ? .white.opacity(0.2) : .red,
                            action: { callManager.toggleVideo() }
                        )
                    .frame(maxWidth: .infinity)   // equal share of the row: evenly spaced
                    }
                    
                    CallControlButton(
                        icon: callManager.isSpeakerEnabled ? "speaker.wave.3.fill" : "speaker.fill",
                        color: .white,
                        backgroundColor: callManager.isSpeakerEnabled ? .blue : .white.opacity(0.2),
                        action: { callManager.toggleSpeaker() }
                    )
                    .frame(maxWidth: .infinity)   // equal share of the row: evenly spaced
                    
                    if call.isVideo {
                        CallControlButton(
                            icon: "camera.rotate.fill",
                            color: .white,
                            backgroundColor: .white.opacity(0.2),
                            action: { callManager.switchCamera() }
                        )
                    .frame(maxWidth: .infinity)   // equal share of the row: evenly spaced
                    }
                }
                .padding(.horizontal, DS.spacingL)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Main action row (always visible)
            HStack(spacing: 60) {
                if isIncoming && callManager.callStatus == .incoming {
                    CallControlButton(
                        icon: "phone.fill",
                        color: .white,
                        backgroundColor: .green,
                        size: 80,
                        action: { answerCall() }
                    )
                    
                    CallControlButton(
                        icon: "phone.down.fill",
                        color: .white,
                        backgroundColor: .red,
                        size: 80,
                        action: { declineCall() }
                    )
                } else {
                    CallControlButton(
                        icon: "phone.down.fill",
                        color: .white,
                        backgroundColor: .red,
                        size: 80,
                        action: { endCall() }
                    )
                }
            }
            .padding(.bottom, DS.spacingXL)
        }
        .animation(.easeInOut(duration: 0.3), value: showControls)
    }
    
    // MARK: - Status Overlay
    
    private var statusOverlay: some View {
        VStack {
            Spacer()
            if callManager.callStatus != .connected && callManager.callStatus != .idle {
                HStack(spacing: DS.spacingS) {
                    if callManager.callStatus != .failed && callManager.callStatus != .disconnected {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(statusText)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, DS.spacingL)
                .padding(.vertical, DS.spacingM)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .transition(.opacity)
            }
            Spacer()
            Spacer()   // sits a little above center, clear of the controls
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.25), value: callManager.callStatus)
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
        Haptics.tap()
        Task {
            await callManager.rejectCall()
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func endCall() {
        Haptics.tap()
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
        case .connected:
            Haptics.success()
        case .failed:
            Haptics.failure()
        case .ended:
            Haptics.warning()
        default:
            break
        }
        switch status {
        case .ended, .failed:
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                presentationMode.wrappedValue.dismiss()
            }
        default:
            break
        }
    }
    
    private var otherPartyId: String {
        call.calleeId == authManager.currentUserId ? call.callerId : call.calleeId
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
