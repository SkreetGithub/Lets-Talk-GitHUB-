import Foundation
import WebRTC
import AVFoundation

// MARK: - WebRTC Call Manager
class WebRTCCallManager: NSObject, ObservableObject {
    static let shared = WebRTCCallManager()
    
    @Published var isInCall = false
    @Published var isVideoEnabled = true
    @Published var isAudioEnabled = true
    @Published var isSpeakerEnabled = false
    @Published var callStatus: WebRTCCallStatus = .idle
    @Published var currentCall: Call?
    @Published var connectionState: RTCIceConnectionState = .new
    
    private var peerConnection: RTCPeerConnection?
    private var localVideoTrack: RTCVideoTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    private var videoCapturer: RTCCameraVideoCapturer?
    private var dataChannel: RTCDataChannel?
    
    private let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
    
    private let configuration: RTCConfiguration = {
        return STUNTurnConfiguration.shared.getRTCConfiguration()
    }()
    
    private var signalingService = FirebaseSignalingService.shared
    private var audioSession: RTCAudioSession?
    
    override init() {
        super.init()
        setupAudioSession()
        signalingService.addDelegate(self)
        signalingService.startListeningForIncomingCalls()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        audioSession = RTCAudioSession.sharedInstance()
        audioSession?.lockForConfiguration()
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
            try audioSession?.setActive(true)
        } catch {
            print("Error setting up audio session: \(error)")
        }
        audioSession?.unlockForConfiguration()
    }
    
    // MARK: - Call Management
    
    func startCall(to userId: String, isVideo: Bool = true) async throws {
        guard !isInCall else {
            throw CallError.alreadyInCall
        }
        
        callStatus = .initiating
        isVideoEnabled = isVideo
        
        // Create call in Supabase-backed signaling
        let callId = try await signalingService.createCall(to: userId, isVideo: isVideo)
        currentCall = Call(
            id: callId,
            callerId: AuthManager.shared.currentUserId ?? "",
            calleeId: userId,
            isVideo: isVideo,
            status: .initiated,
            createdAt: Date(),
            participants: [AuthManager.shared.currentUserId ?? "", userId]
        )
        
        // Create peer connection
        createPeerConnection()
        
        // Create media tracks
        createMediaTracks(isVideo: isVideo)
        
        // Create data channel
        createDataChannel()
        
        // Create and send offer
        try await createOffer()
        
        // Update call status
        await MainActor.run {
            self.isInCall = true
            self.callStatus = .connecting
        }
        
        // Listen for signaling messages
        signalingService.listenForSignalingMessages(callId: callId)
    }
    
    func answerCall(callId: String, isVideo: Bool = true) async throws {
        guard !isInCall else {
            throw CallError.alreadyInCall
        }
        
        callStatus = .answering
        isVideoEnabled = isVideo
        
        // Answer call in Supabase-backed signaling
        try await signalingService.answerCall(callId: callId, isVideo: isVideo)
        // Keep a local reference for subsequent signaling sends.
        currentCall = Call(
            id: callId,
            callerId: currentCall?.callerId ?? "",
            calleeId: AuthManager.shared.currentUserId ?? "",
            isVideo: isVideo,
            status: .answered,
            createdAt: Date(),
            participants: [currentCall?.callerId ?? "", AuthManager.shared.currentUserId ?? ""].filter { !$0.isEmpty }
        )
        
        // Create peer connection
        createPeerConnection()
        
        // Create media tracks
        createMediaTracks(isVideo: isVideo)
        
        // Listen for signaling messages
        signalingService.listenForSignalingMessages(callId: callId)
        
        await MainActor.run {
            self.isInCall = true
            self.callStatus = .connected
        }
    }
    
    func endCall() async {
        guard isInCall else { return }
        
        callStatus = .ending
        
        // End call in Supabase-backed signaling
        if let callId = currentCall?.id {
            try? await signalingService.endCall(callId: callId)
        }
        
        // Clean up WebRTC resources
        cleanup()
        
        await MainActor.run {
            self.isInCall = false
            self.callStatus = .idle
            self.currentCall = nil
            self.connectionState = .new
        }
    }
    
    func rejectCall() async {
        guard let callId = currentCall?.id else { return }
        
        try? await signalingService.rejectCall(callId: callId)
        
        await MainActor.run {
            self.callStatus = .idle
            self.currentCall = nil
        }
    }
    
    // MARK: - Media Controls
    
    func toggleVideo() {
        isVideoEnabled.toggle()
        localVideoTrack?.isEnabled = isVideoEnabled
        
        if !isVideoEnabled {
            videoCapturer?.stopCapture()
        } else {
            startVideoCapture()
        }
    }
    
    func toggleAudio() {
        isAudioEnabled.toggle()
        localAudioTrack?.isEnabled = isAudioEnabled
    }
    
    func toggleSpeaker() {
        isSpeakerEnabled.toggle()
        
        audioSession?.lockForConfiguration()
        do {
            if isSpeakerEnabled {
                try audioSession?.overrideOutputAudioPort(.speaker)
            } else {
                try audioSession?.overrideOutputAudioPort(.none)
            }
        } catch {
            print("Error toggling speaker: \(error)")
        }
        audioSession?.unlockForConfiguration()
    }
    
    func switchCamera() {
        guard let capturer = videoCapturer else { return }
        
        let currentPosition = getCurrentCameraPosition()
        let newPosition: AVCaptureDevice.Position = currentPosition == .front ? .back : .front
        
        guard let device = getCameraDevice(position: newPosition) else { return }
        guard let format = getBestFormat(for: device) else { return }
        
        capturer.stopCapture {
            capturer.startCapture(with: device, format: format, fps: 30)
        }
    }
    
    // MARK: - Video Views
    
    func setLocalVideoView(_ view: RTCMTLVideoView) {
        localVideoTrack?.add(view)
    }
    
    func setRemoteVideoView(_ view: RTCMTLVideoView) {
        remoteVideoTrack?.add(view)
    }
    
    // MARK: - Private Methods
    
    private func createPeerConnection() {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "true"
            ],
            optionalConstraints: nil
        )
        
        peerConnection = factory.peerConnection(
            with: configuration,
            constraints: constraints,
            delegate: self
        )
    }
    
    private func createMediaTracks(isVideo: Bool) {
        // Create audio track
        let audioSource = factory.audioSource(with: nil)
        localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        peerConnection?.add(localAudioTrack!, streamIds: ["stream0"])
        
        if isVideo {
            // Create video track
            let videoSource = factory.videoSource()
            videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
            localVideoTrack = factory.videoTrack(with: videoSource, trackId: "video0")
            peerConnection?.add(localVideoTrack!, streamIds: ["stream0"])
            
            startVideoCapture()
        }
    }
    
    private func startVideoCapture() {
        guard let capturer = videoCapturer else { return }
        
        let device = getCameraDevice(position: .front) ?? getCameraDevice(position: .back)
        guard let cameraDevice = device else { return }
        guard let format = getBestFormat(for: cameraDevice) else { return }
        
        capturer.startCapture(with: cameraDevice, format: format, fps: 30)
    }
    
    private func createDataChannel() {
        let config = RTCDataChannelConfiguration()
        config.isOrdered = true
        config.isNegotiated = false
        
        dataChannel = peerConnection?.dataChannel(forLabel: "dataChannel", configuration: config)
        dataChannel?.delegate = self
    }
    
    private func createOffer() async throws {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "true"
            ],
            optionalConstraints: nil
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            peerConnection?.offer(for: constraints) { [weak self] sdp, error in
                guard let self = self else {
                    continuation.resume(throwing: CallError.unknown)
                    return
                }
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sdp = sdp else {
                    continuation.resume(throwing: CallError.unknown)
                    return
                }
                
                self.peerConnection?.setLocalDescription(sdp) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    Task {
                        do {
                            try await self.signalingService.sendOffer(callId: self.currentCall?.id ?? "", offer: sdp)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }
    
    private func createAnswer() async throws {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "true"
            ],
            optionalConstraints: nil
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            peerConnection?.answer(for: constraints) { [weak self] sdp, error in
                guard let self = self else {
                    continuation.resume(throwing: CallError.unknown)
                    return
                }
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sdp = sdp else {
                    continuation.resume(throwing: CallError.unknown)
                    return
                }
                
                self.peerConnection?.setLocalDescription(sdp) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    Task {
                        do {
                            try await self.signalingService.sendAnswer(callId: self.currentCall?.id ?? "", answer: sdp)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }
    
    private func cleanup() {
        videoCapturer?.stopCapture()
        peerConnection?.close()
        
        localVideoTrack = nil
        remoteVideoTrack = nil
        localAudioTrack = nil
        remoteAudioTrack = nil
        dataChannel = nil
        peerConnection = nil
        videoCapturer = nil
    }
    
    // MARK: - Camera Helpers
    
    private func getCurrentCameraPosition() -> AVCaptureDevice.Position {
        // This would need to be tracked in a real implementation
        return .front
    }
    
    private func getCameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return RTCCameraVideoCapturer.captureDevices().first { $0.position == position }
    }
    
    private func getBestFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        return RTCCameraVideoCapturer.supportedFormats(for: device).first
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCCallManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("Signaling state changed: \(stateChanged.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("Stream added")
        
        if let videoTrack = stream.videoTracks.first {
            remoteVideoTrack = videoTrack
        }
        
        if let audioTrack = stream.audioTracks.first {
            remoteAudioTrack = audioTrack
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("Stream removed")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("Negotiation needed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("ICE connection state changed: \(newState.rawValue)")
        
        DispatchQueue.main.async {
            self.connectionState = newState
            
            switch newState {
            case .connected, .completed:
                self.callStatus = .connected
            case .disconnected:
                self.callStatus = .disconnected
            case .failed:
                self.callStatus = .failed
            case .closed:
                self.callStatus = .ended
            default:
                break
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("ICE gathering state changed: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("Generated ICE candidate")
        
        Task {
            try? await signalingService.sendIceCandidate(
                callId: currentCall?.id ?? "",
                candidate: candidate
            )
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("ICE candidates removed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("Data channel opened")
    }
}

// MARK: - RTCDataChannelDelegate

extension WebRTCCallManager: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("Data channel state changed: \(dataChannel.readyState.rawValue)")
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        if let message = String(data: buffer.data, encoding: .utf8) {
            print("Received data channel message: \(message)")
        }
    }
}

// MARK: - FirebaseSignalingDelegate

extension WebRTCCallManager: FirebaseSignalingDelegate {
    func firebaseSignaling(_ service: FirebaseSignalingService, didReceiveCallUpdate call: Call) {
        DispatchQueue.main.async {
            self.currentCall = call
        }
    }
    
    func firebaseSignaling(_ service: FirebaseSignalingService, didReceiveIncomingCall call: Call) {
        DispatchQueue.main.async {
            self.currentCall = call
            self.callStatus = .incoming
        }
    }
    
    func firebaseSignaling(_ service: FirebaseSignalingService, didReceiveSignalingMessage message: SignalingMessage) {
        switch message.type {
        case .offer:
            handleOffer(message: message)
        case .answer:
            handleAnswer(message: message)
        case .iceCandidate:
            handleIceCandidate(message: message)
        case .callEnd:
            Task {
                await endCall()
            }
        }
    }
    
    func firebaseSignaling(_ service: FirebaseSignalingService, didReceiveError error: Error) {
        print("Signaling error: \(error)")
        DispatchQueue.main.async {
            self.callStatus = .failed
        }
    }
    
    private func handleOffer(message: SignalingMessage) {
        guard let sdp = message.sdp else { return }
        
        let offer = RTCSessionDescription(type: .offer, sdp: sdp)
        peerConnection?.setRemoteDescription(offer) { [weak self] error in
            if let error = error {
                print("Error setting remote description: \(error)")
                return
            }
            
            Task {
                try? await self?.createAnswer()
            }
        }
    }
    
    private func handleAnswer(message: SignalingMessage) {
        guard let sdp = message.sdp else { return }
        
        let answer = RTCSessionDescription(type: .answer, sdp: sdp)
        peerConnection?.setRemoteDescription(answer) { error in
            if let error = error {
                print("Error setting remote description: \(error)")
            }
        }
    }
    
    private func handleIceCandidate(message: SignalingMessage) {
        guard let candidate = message.candidate,
              let sdpMLineIndex = message.sdpMLineIndex,
              let sdpMid = message.sdpMid else { return }
        
        let iceCandidate = RTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        peerConnection?.add(iceCandidate) { error in
            if let error = error {
                print("Error adding ICE candidate: \(error)")
            }
        }
    }
}

// MARK: - Call Status

enum WebRTCCallStatus {
    case idle
    case incoming
    case initiating
    case answering
    case connecting
    case connected
    case disconnected
    case failed
    case ending
    case ended
}

// MARK: - Call Error

enum CallError: Error, LocalizedError {
    case alreadyInCall
    case userNotAuthenticated
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .alreadyInCall:
            return "Already in a call"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .networkError:
            return "Network error"
        case .unknown:
            return "Unknown error"
        }
    }
}
