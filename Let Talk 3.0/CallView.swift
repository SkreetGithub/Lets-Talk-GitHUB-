import SwiftUI
import WebRTC
import AVFoundation

struct CallView: View {
    let contact: Contact
    let isVideo: Bool
    @StateObject private var viewModel = CallViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var showTranslationBubble = false
    @State private var translatedText = ""
    @State private var isShowingLocalVideo = true
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            // Main Content
            if isVideo {
                videoCallView
            } else {
                audioCallView
            }
            
            // Call Controls
            VStack {
                Spacer()
                callControls
                    .padding(.bottom, 50)
            }
            
            // Translation Bubble
            if showTranslationBubble && !translatedText.isEmpty {
                translationBubble
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            viewModel.startCall(to: contact, isVideo: isVideo)
            if !isVideo {
                viewModel.playDialTone()
            }
        }
        .onDisappear {
            viewModel.endCall()
            viewModel.stopDialTone()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred")
        }
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black,
                Color.blue.opacity(0.8),
                Color.purple.opacity(0.6)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Video Call View
    private var videoCallView: some View {
        GeometryReader { geometry in
            ZStack {
                // Remote Video (Full Screen)
                VideoView(isRemote: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                
                // Local Video (Picture in Picture) - Top Right
                if isShowingLocalVideo {
                    VideoView(isRemote: false)
                        .frame(width: 120, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .position(x: geometry.size.width - 80, y: 100)
                }
                
                // Contact Info Overlay (Top Left)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        // Contact Profile Image (Small)
                        ProfileImageView(
                            imageURL: contact.imageURL,
                            placeholderText: contact.initials
                        )
                        .frame(width: 50, height: 50)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(viewModel.callStatus)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    if viewModel.isConnected {
                        Text(viewModel.callDuration)
                            .font(.title3)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.4))
                    }
                )
                .position(x: 100, y: 100)
            }
        }
    }
    
    // MARK: - Audio Call View
    private var audioCallView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Contact Profile Image (Large)
            ProfileImageView(
                imageURL: contact.imageURL,
                placeholderText: contact.initials
            )
            .frame(width: 200, height: 200)
            .scaleEffect(viewModel.isConnected ? 1.0 : 0.9)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isConnected)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Contact Information
            VStack(spacing: 12) {
                Text(contact.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(contact.phone)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                
                // Call Status
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .scaleEffect(viewModel.isConnected ? 1.0 : 1.2)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), 
                                 value: viewModel.isConnected)
                    
                    Text(viewModel.callStatus)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // Call Duration
                if viewModel.isConnected {
                    Text(viewModel.callDuration)
                        .font(.title2)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Call Controls
    private var callControls: some View {
        HStack(spacing: 40) {
            // Microphone Button
            CallControlButton(
                icon: viewModel.isMicEnabled ? "mic.fill" : "mic.slash.fill",
                color: viewModel.isMicEnabled ? .white : .red,
                backgroundColor: viewModel.isMicEnabled ? Color.gray.opacity(0.3) : Color.red.opacity(0.3)
            ) {
                viewModel.toggleMicrophone()
            }
            
            // End Call Button (Center)
            CallControlButton(
                icon: "phone.down.fill",
                color: .white,
                backgroundColor: .red,
                size: 70
            ) {
                viewModel.endCall()
                presentationMode.wrappedValue.dismiss()
            }
            
            if isVideo {
                // Camera Toggle Button
                CallControlButton(
                    icon: viewModel.isCameraEnabled ? "video.fill" : "video.slash.fill",
                    color: viewModel.isCameraEnabled ? .white : .red,
                    backgroundColor: viewModel.isCameraEnabled ? Color.gray.opacity(0.3) : Color.red.opacity(0.3)
                ) {
                    viewModel.toggleCamera()
                    isShowingLocalVideo = viewModel.isCameraEnabled
                }
                
                // Switch Camera Button
                CallControlButton(
                    icon: "camera.rotate.fill",
                    color: .white,
                    backgroundColor: Color.gray.opacity(0.3)
                ) {
                    viewModel.switchCamera()
                }
            } else {
                // Speaker Button
                CallControlButton(
                    icon: viewModel.isSpeakerEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    color: viewModel.isSpeakerEnabled ? .white : .red,
                    backgroundColor: viewModel.isSpeakerEnabled ? Color.gray.opacity(0.3) : Color.red.opacity(0.3)
                ) {
                    viewModel.toggleSpeaker()
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.black.opacity(0.6))
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Translation Bubble
    private var translationBubble: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Translation")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(translatedText)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.blue.opacity(0.8))
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .frame(maxWidth: 250)
            }
            
            Spacer()
        }
        .padding(.top, 200)
        .padding(.trailing, 20)
    }
}

struct CallControlButton: View {
    let icon: String
    let color: Color
    var backgroundColor: Color = Color.gray.opacity(0.3)
    var size: CGFloat = 60
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(backgroundColor)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: color)
    }
}

struct VideoView: UIViewRepresentable {
    let isRemote: Bool
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let videoView = RTCMTLVideoView()
        videoView.videoContentMode = .scaleAspectFill
        videoView.backgroundColor = .black
        
        if isRemote {
            WebRTCService.shared.setRemoteVideoView(videoView)
        } else {
            WebRTCService.shared.setLocalVideoView(videoView)
        }
        return videoView
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // Ensure the video view is properly configured
        uiView.videoContentMode = .scaleAspectFill
        uiView.backgroundColor = .black
    }
}


class CallViewModel: ObservableObject, WebRTCServiceDelegate {
    @Published var callStatus = "Connecting..."
    @Published var isConnected = false
    @Published var isMicEnabled = true
    @Published var isCameraEnabled = true
    @Published var isSpeakerEnabled = true
    @Published var error: Error?
    @Published var showError = false
    @Published var callDuration = "00:00"
    
    private let webRTCService = WebRTCService.shared
    private var callTimer: Timer?
    private var callStartTime: Date?
    private var dialTonePlayer: AVAudioPlayer?
    
    init() {
        webRTCService.delegate = self
    }
    
    func startCall(to contact: Contact, isVideo: Bool) {
        Task {
            do {
                callStatus = "Connecting..."
                try await webRTCService.startCall(to: contact.phone, isVideo: isVideo)
                await MainActor.run {
                    callStatus = "Connected"
                    isConnected = true
                    startCallTimer()
                }
            } catch {
                await MainActor.run {
                    callStatus = "Failed to connect"
                    isConnected = false
                    self.error = error
                    showError = true
                }
            }
        }
    }
    
    func endCall() {
        webRTCService.endCall()
        callTimer?.invalidate()
        callTimer = nil
    }
    
    func toggleMicrophone() {
        isMicEnabled.toggle()
        webRTCService.setAudioEnabled(isMicEnabled)
    }
    
    func toggleCamera() {
        isCameraEnabled.toggle()
        webRTCService.setVideoEnabled(isCameraEnabled)
    }
    
    func toggleSpeaker() {
        isSpeakerEnabled.toggle()
        // Implement speaker toggle
    }
    
    func switchCamera() {
        webRTCService.switchCamera()
    }
    
    private func startCallTimer() {
        callStartTime = Date()
        callTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateCallDuration()
        }
    }
    
    private func updateCallDuration() {
        guard let startTime = callStartTime else { return }
        
        let duration = Int(Date().timeIntervalSince(startTime))
        let minutes = duration / 60
        let seconds = duration % 60
        
        callDuration = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Dialtone Functions
    func playDialTone() {
        // Create a more realistic dial tone using AVAudioEngine
        guard let url = Bundle.main.url(forResource: "dialtone", withExtension: "wav") else {
            // Fallback to system sound if custom dial tone not available
            let dialToneSound = SystemSoundID(1000)
            AudioServicesPlaySystemSound(dialToneSound)
            
            // Repeat dialtone every 2 seconds
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if self?.isConnected == false {
                    AudioServicesPlaySystemSound(dialToneSound)
                } else {
                    timer.invalidate()
                }
            }
            return
        }
        
        do {
            dialTonePlayer = try AVAudioPlayer(contentsOf: url)
            dialTonePlayer?.numberOfLoops = -1 // Loop indefinitely
            dialTonePlayer?.volume = 0.3
            dialTonePlayer?.play()
        } catch {
            print("Error playing dial tone: \(error)")
            // Fallback to system sound
            let dialToneSound = SystemSoundID(1000)
            AudioServicesPlaySystemSound(dialToneSound)
        }
    }
    
    func stopDialTone() {
        // Stop any ongoing dialtone
        dialTonePlayer?.stop()
        dialTonePlayer = nil
    }
    
    deinit {
        endCall()
        stopDialTone()
    }
    
    // MARK: - WebRTCServiceDelegate
    func webRTCService(_ service: WebRTCService, didEndCall callId: String?) {
        DispatchQueue.main.async {
            self.callStatus = "Call ended"
            self.isConnected = false
            self.stopDialTone()
        }
    }
    
    func webRTCService(_ service: WebRTCService, didStartCall targetNumber: String, isVideo: Bool) {
        DispatchQueue.main.async {
            self.callStatus = "Calling \(targetNumber)..."
        }
    }
    
    func webRTCService(_ service: WebRTCService, didReceiveRemoteVideoTrack track: RTCVideoTrack) {
        DispatchQueue.main.async {
            self.callStatus = "Connected"
            self.isConnected = true
            self.stopDialTone()
        }
    }
    
    func webRTCService(_ service: WebRTCService, didReceiveRemoteAudioTrack track: RTCAudioTrack) {
        DispatchQueue.main.async {
            self.callStatus = "Connected"
            self.isConnected = true
            self.stopDialTone()
        }
    }
    
    func webRTCService(_ service: WebRTCService, didReceiveData data: Data) {
        // Handle data channel messages if needed
    }
    
    func webRTCService(_ service: WebRTCService, didChangeConnectionState state: RTCIceConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected, .completed:
                self.callStatus = "Connected"
                self.isConnected = true
                self.stopDialTone()
            case .disconnected:
                self.callStatus = "Disconnected"
                self.isConnected = false
            case .failed:
                self.callStatus = "Connection failed"
                self.isConnected = false
            case .closed:
                self.callStatus = "Call ended"
                self.isConnected = false
            default:
                break
            }
        }
    }
    
    func webRTCService(_ service: WebRTCService, didReceiveError error: Error) {
        DispatchQueue.main.async {
            self.error = error
            self.showError = true
            self.callStatus = "Error occurred"
            self.isConnected = false
        }
    }
}

// BlurView is defined in TranslatorView.swift

struct CallView_Previews: PreviewProvider {
    static var previews: some View {
        CallView(
            contact: Contact(
                name: "John Doe",
                phone: "123-456-7890",
                email: "john@example.com"
            ),
            isVideo: true
        )
    }
}
