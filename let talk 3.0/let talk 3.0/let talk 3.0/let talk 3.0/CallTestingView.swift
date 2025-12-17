import SwiftUI
import WebRTC

struct CallTestingView: View {
    @StateObject private var callManager = WebRTCCallManager.shared
    @EnvironmentObject var authManager: AuthManager
    
    @State private var targetUserId = ""
    @State private var isVideoCall = true
    @State private var showCallInterface = false
    @State private var testCall: Call?
    @State private var connectionStatus = "Disconnected"
    @State private var iceConnectionState = "New"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Text("WebRTC Call Testing")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Test video and audio calls with Supabase signaling")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Connection Status
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(connectionStatusColor)
                            .frame(width: 12, height: 12)
                        
                        Text("Connection: \(connectionStatus)")
                            .font(.headline)
                    }
                    
                    Text("ICE State: \(iceConnectionState)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Call Controls
                VStack(spacing: 16) {
                    // Target User ID
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target User ID")
                            .font(.headline)
                        
                        TextField("Enter user ID to call", text: $targetUserId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Call Type Toggle
                    HStack {
                        Text("Call Type:")
                            .font(.headline)
                        
                        Spacer()
                        
                        Picker("Call Type", selection: $isVideoCall) {
                            Text("Audio Only").tag(false)
                            Text("Video Call").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 200)
                    }
                    
                    // Call Buttons
                    HStack(spacing: 20) {
                        Button(action: startTestCall) {
                            HStack {
                                Image(systemName: "phone.fill")
                                Text("Start Call")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(targetUserId.isEmpty || callManager.isInCall)
                        
                        Button(action: endTestCall) {
                            HStack {
                                Image(systemName: "phone.down.fill")
                                Text("End Call")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!callManager.isInCall)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(15)
                .shadow(radius: 5)
                
                // Call Status
                if callManager.isInCall {
                    VStack(spacing: 12) {
                        Text("Call Status: \(callStatusText)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 20) {
                            // Audio Toggle
                            Button(action: { callManager.toggleAudio() }) {
                                VStack {
                                    Image(systemName: callManager.isAudioEnabled ? "mic.fill" : "mic.slash.fill")
                                        .font(.title2)
                                    Text("Audio")
                                        .font(.caption)
                                }
                                .foregroundColor(callManager.isAudioEnabled ? .green : .red)
                            }
                            
                            // Video Toggle
                            if isVideoCall {
                                Button(action: { callManager.toggleVideo() }) {
                                    VStack {
                                        Image(systemName: callManager.isVideoEnabled ? "video.fill" : "video.slash.fill")
                                            .font(.title2)
                                        Text("Video")
                                            .font(.caption)
                                    }
                                    .foregroundColor(callManager.isVideoEnabled ? .green : .red)
                                }
                            }
                            
                            // Speaker Toggle
                            Button(action: { callManager.toggleSpeaker() }) {
                                VStack {
                                    Image(systemName: callManager.isSpeakerEnabled ? "speaker.wave.3.fill" : "speaker.fill")
                                        .font(.title2)
                                    Text("Speaker")
                                        .font(.caption)
                                }
                                .foregroundColor(callManager.isSpeakerEnabled ? .blue : .gray)
                            }
                            
                            // Camera Switch
                            if isVideoCall {
                                Button(action: { callManager.switchCamera() }) {
                                    VStack {
                                        Image(systemName: "camera.rotate.fill")
                                            .font(.title2)
                                        Text("Switch")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Test Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Information")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Use a second device or simulator to test calls")
                        Text("• Ensure both devices are on the same network or have internet")
                        Text("• Video calls require camera permissions")
                        Text("• Audio calls work with microphone permissions")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("Call Testing")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            setupCallManager()
        }
        .onChange(of: callManager.connectionState) { state in
            updateConnectionStatus()
        }
        .onChange(of: callManager.callStatus) { status in
            updateCallStatus()
        }
        .fullScreenCover(isPresented: $showCallInterface) {
            if let call = testCall {
                CallInterfaceView(call: call, isIncoming: false)
            }
        }
    }
    
    // MARK: - Methods
    
    private func setupCallManager() {
        // Set up call manager observers
        updateConnectionStatus()
        updateCallStatus()
    }
    
    private func startTestCall() {
        guard !targetUserId.isEmpty else { return }
        
        Task {
            do {
                try await callManager.startCall(to: targetUserId, isVideo: isVideoCall)
                
                // Create test call object
                testCall = Call(
                    id: UUID().uuidString,
                    callerId: authManager.currentUserId ?? "",
                    calleeId: targetUserId,
                    isVideo: isVideoCall,
                    status: .initiated,
                    createdAt: Date(),
                    participants: [authManager.currentUserId ?? "", targetUserId]
                )
                
                await MainActor.run {
                    showCallInterface = true
                }
            } catch {
                print("Error starting call: \(error)")
            }
        }
    }
    
    private func endTestCall() {
        Task {
            await callManager.endCall()
            await MainActor.run {
                showCallInterface = false
                testCall = nil
            }
        }
    }
    
    private func updateConnectionStatus() {
        switch callManager.connectionState {
        case .new:
            connectionStatus = "New"
        case .checking:
            connectionStatus = "Checking"
        case .connected:
            connectionStatus = "Connected"
        case .completed:
            connectionStatus = "Completed"
        case .failed:
            connectionStatus = "Failed"
        case .disconnected:
            connectionStatus = "Disconnected"
        case .closed:
            connectionStatus = "Closed"
        case .count:
            connectionStatus = "Unknown"
        @unknown default:
            connectionStatus = "Unknown"
        }
        
        iceConnectionState = connectionStatus
    }
    
    private func updateCallStatus() {
        // Update UI based on call status
    }
    
    private var connectionStatusColor: Color {
        switch callManager.connectionState {
        case .connected, .completed:
            return .green
        case .checking:
            return .yellow
        case .failed, .disconnected, .closed:
            return .red
        default:
            return .gray
        }
    }
    
    private var callStatusText: String {
        switch callManager.callStatus {
        case .idle:
            return "Idle"
        case .incoming:
            return "Incoming"
        case .initiating:
            return "Initiating"
        case .answering:
            return "Answering"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        case .failed:
            return "Failed"
        case .ending:
            return "Ending"
        case .ended:
            return "Ended"
        }
    }
}

struct CallTestingView_Previews: PreviewProvider {
    static var previews: some View {
        CallTestingView()
            .environmentObject(AuthManager.shared)
    }
}
