import SwiftUI
import AVFoundation
import WebRTC
import Speech

// MARK: - Translation Protocol
protocol TranslationEnabled {
    var translationViewModel: TranslationViewModel { get }
    var userLanguage: String { get set }
    var sourceLanguage: String { get set }
    var otherUserLanguage: String { get set }
    var targetLanguage: String { get set }
}

// MARK: - Video Stream View
struct VideoStreamView: View, TranslationEnabled {
    @State private var isStreaming = false
    @State private var translatedText = ""
    @State private var webRTCService = WebRTCService()
    @StateObject private var _translationViewModel = TranslationViewModel()
    @State private var videoCapturer: RTCCameraVideoCapturer?
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var isMuted = false
    @State private var isVideoEnabled = true
    @State private var callDuration: TimeInterval = 0
    @State private var callTimer: Timer?
    @EnvironmentObject var settingsManager: SettingsManager
    
    // Language properties with internal access
    @State internal var userLanguage = UserDefaults.standard.string(forKey: "userLanguage") ?? "en"
    @State internal var sourceLanguage = UserDefaults.standard.string(forKey: "sourceLanguage") ?? "en"
    @State internal var otherUserLanguage = UserDefaults.standard.string(forKey: "otherUserLanguage") ?? "es"
    @State internal var targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "es"
    
    // Protocol requirement implementation
    internal var translationViewModel: TranslationViewModel {
        _translationViewModel
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Remote video view
                VideoPreviewView(webRTCService: webRTCService)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                
                // Local video preview (picture-in-picture)
                HStack {
                    Spacer()
                    LocalVideoPreview()
                        .frame(width: 120, height: 160)
                        .cornerRadius(12)
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                
                // Translation overlay
                if !translatedText.isEmpty {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 8) {
                                Text("Translated:")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text(translatedText)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial)
                                    )
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
                
                // Call controls
                VStack(spacing: 20) {
                    // Call info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("John Doe")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(formatCallDuration(callDuration))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        // Translation status
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .foregroundColor(.white)
                            Text("\(sourceLanguage.uppercased()) → \(targetLanguage.uppercased())")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .padding(.horizontal)
                    
                    // Control buttons
                    HStack(spacing: 40) {
                        // Mute button
                        Button(action: toggleMute) {
                            Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(isMuted ? Color.red : Color(.systemGray))
                                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Video toggle
                        Button(action: toggleVideo) {
                            Image(systemName: isVideoEnabled ? "video.fill" : "video.slash.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(isVideoEnabled ? Color(.systemGray) : Color.red)
                                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Translation toggle
                        Button(action: toggleTranslation) {
                            Image(systemName: translationViewModel.isTranslating ? "globe" : "globe")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(translationViewModel.isTranslating ? Color.blue : Color(.systemGray))
                                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // End call button
                        Button(action: endCall) {
                            Image(systemName: "phone.down.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.bottom, 40)
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .onAppear {
            setupAudioSession()
            setupTranslation()
            startCallTimer()
        }
        .onDisappear {
            stopCallTimer()
        }
        .alert("Connection Error", isPresented: $showErrorAlert) {
            Button("Retry") {
                // TODO: Implement reconnect functionality
                showErrorAlert = false
            }
            Button("Cancel", role: .cancel) {
                showErrorAlert = false
            }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
        .onChange(of: isStreaming) { streaming in
            if streaming {
                handleConnectionStateChange(.connected)
            }
        }
    }
    
    // MARK: - Call Control Functions
    private func toggleMute() {
        isMuted.toggle()
        // webRTCService.setMicrophoneMuted(isMuted)
    }
    
    private func toggleVideo() {
        isVideoEnabled.toggle()
        // webRTCService.setVideoEnabled(isVideoEnabled)
    }
    
    private func toggleTranslation() {
        if translationViewModel.isTranslating {
            stopTranslation()
        } else {
            startTranslation()
        }
    }
    
    private func endCall() {
        stopCallTimer()
        // webRTCService.endCall()
        // Handle call end navigation
    }
    
    private func startCallTimer() {
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            callDuration += 1
        }
    }
    
    private func stopCallTimer() {
        callTimer?.invalidate()
        callTimer = nil
    }
    
    private func formatCallDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Translation Functions
    func startStreaming() {
        isStreaming = true
        
        // webRTCService.createPeerConnection()
        // webRTCService.createMediaSenders()
        
        // Initialize video capture
        let camera = AVCaptureDevice.default(for: .video)
        if let camera = camera {
            videoCapturer = RTCCameraVideoCapturer()
            if let format = RTCCameraVideoCapturer.supportedFormats(for: camera).first {
                videoCapturer?.startCapture(with: camera, format: format, fps: 30)
            }
        }
    }

    func translateAudio(inputText: String) {
        translationViewModel.translate(text: inputText)
        // TODO: Handle translation result when TranslationViewModel is updated
        DispatchQueue.main.async {
            self.translatedText = "[Translated] \(inputText)"
        }
    }

    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: .allowBluetooth)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    private func handleConnectionStateChange(_ state: ConnectionState) {
        switch state {
        case .failed(let error):
            errorMessage = error.localizedDescription
            showErrorAlert = true
        case .connected:
            print("Video streaming connected")
        default:
            break
        }
    }
    
    enum ConnectionState {
        case connected
        case failed(Error)
        case disconnected
    }

    func setupTranslation() {
        guard let userId = AuthManager.shared.currentUserId else { return }
        
        let userLanguage = UserDefaults.standard.string(forKey: "userLanguage") ?? "en"
        self.userLanguage = userLanguage
        self.sourceLanguage = userLanguage
        
        let otherLanguage = UserDefaults.standard.string(forKey: "otherUserLanguage") ?? "es"
        self.otherUserLanguage = otherLanguage
        self.targetLanguage = otherLanguage
    }
    
    func startTranslation() {
        translationViewModel.isTranslating = true
        // Simulate translation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.translatedText = "Translated text will appear here"
        }
    }
    
    func stopTranslation() {
        translationViewModel.isTranslating = false
        translatedText = ""
    }
}

// MARK: - Video Preview Views
struct VideoPreviewView: UIViewControllerRepresentable {
    let webRTCService: WebRTCService
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let videoView = RTCMTLVideoView(frame: .zero)
        
        viewController.view = videoView
        videoView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
            videoView.leftAnchor.constraint(equalTo: viewController.view.leftAnchor),
            videoView.rightAnchor.constraint(equalTo: viewController.view.rightAnchor)
        ])
        
        // Set up video view delegate
        // videoView.delegate = webRTCService
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update video view if needed
    }
}

struct LocalVideoPreview: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
            
            VStack {
                Image(systemName: "person.fill")
                    .font(.title)
                    .foregroundColor(.white)
                
                Text("You")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Button Style (using existing ScaleButtonStyle from TranslatorView)

#Preview {
    VideoStreamView()
        .environmentObject(SettingsManager.shared)
}
