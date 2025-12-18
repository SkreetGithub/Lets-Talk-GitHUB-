import WebRTC
import Foundation
import AVFoundation

protocol WebRTCServiceDelegate: AnyObject {
    func webRTCService(_ service: WebRTCService, didEndCall callId: String?)
    func webRTCService(_ service: WebRTCService, didStartCall targetNumber: String, isVideo: Bool)
    func webRTCService(_ service: WebRTCService, didReceiveRemoteVideoTrack track: RTCVideoTrack)
    func webRTCService(_ service: WebRTCService, didReceiveRemoteAudioTrack track: RTCAudioTrack)
    func webRTCService(_ service: WebRTCService, didReceiveData data: Data)
    func webRTCService(_ service: WebRTCService, didChangeConnectionState state: RTCIceConnectionState)
    func webRTCService(_ service: WebRTCService, didReceiveError error: Error)
}

class WebRTCService: NSObject {
    static let shared = WebRTCService()
    
    private var peerConnection: RTCPeerConnection?
    private var localVideoTrack: RTCVideoTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    private var localDataChannel: RTCDataChannel?
    private var remoteDataChannel: RTCDataChannel?
    private var videoCapturer: RTCCameraVideoCapturer?
    private var currentCaptureDevice: AVCaptureDevice?
    private var localVideoView: RTCMTLVideoView?
    private var remoteVideoView: RTCMTLVideoView?
    private var audioQueue = DispatchQueue(label: "audio.queue")
    private var audioSession: RTCAudioSession?
    private var signalingService = FirebaseSignalingService.shared
    private var currentTarget: String?
    private var isInitiator = false
    private var currentCallId: String?
    private var callParticipants: [String] = []
    private var isMultiCall = false
    private var isInCall = false
    private var isEndingCall = false
    weak var delegate: WebRTCServiceDelegate?
    
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory,
                                      decoderFactory: videoDecoderFactory)
    }()
    
    private let configuration: RTCConfiguration = {
        let config = RTCConfiguration()
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"])
        ]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        return config
    }()
    
    override init() {
        super.init()
        setupAudioSession()
        signalingService.addDelegate(self)
        signalingService.startListeningForIncomingCalls()
    }
    
    private func setupAudioSession() {
        audioSession = RTCAudioSession.sharedInstance()
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            self.audioSession?.lockForConfiguration()
            do {
                try self.audioSession?.setCategory(.playAndRecord)
                try self.audioSession?.setMode(.voiceChat)
                try self.audioSession?.overrideOutputAudioPort(.speaker)
                try self.audioSession?.setActive(true)
            } catch {
                print("Error setting up audio session: \(error)")
            }
            self.audioSession?.unlockForConfiguration()
        }
    }
    
    func startCall(to targetNumber: String, isVideo: Bool = false) async throws {
        isInitiator = true
        currentTarget = targetNumber
        isInCall = true
        isEndingCall = false
        
        // Create call in Supabase-backed signaling
        currentCallId = try await signalingService.createCall(to: targetNumber, isVideo: isVideo)
        
        // Create peer connection
        createPeerConnection()
        
        // Create and add media tracks
        createMediaTracks(isVideo: isVideo)
        
        // Create data channel
        createDataChannel()
        
        // Create and send offer
        createOffer()
        
        // Notify delegate
        await MainActor.run {
            delegate?.webRTCService(self, didStartCall: targetNumber, isVideo: isVideo)
        }
    }
    
    func startVideoCall(to targetNumber: String) async throws {
        try await startCall(to: targetNumber, isVideo: true)
    }
    
    func handleIncomingCall(callId: String, from callerId: String, isVideo: Bool = false) {
        // Show inbound call screen
        InboundCallManager.shared.showIncomingCall(from: callerId, isVideo: isVideo)
    }
    
    func answerCall(callId: String, isVideo: Bool) async throws {
        isInitiator = false
        currentCallId = callId
        isInCall = true
        isEndingCall = false
        
        // Answer call in Supabase-backed signaling
        try await signalingService.answerCall(callId: callId, isVideo: isVideo)
        
        // Create peer connection
        createPeerConnection()
        
        // Create and add media tracks
        createMediaTracks(isVideo: isVideo)
    }
    
    private func createPeerConnection() {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true",
                                 "OfferToReceiveVideo": "true"],
            optionalConstraints: nil
        )
        
        peerConnection = WebRTCService.factory.peerConnection(
            with: configuration,
            constraints: constraints,
            delegate: self
        )
    }
    
    private func createMediaTracks(isVideo: Bool) {
        // Create audio track
        let audioConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        let audioSource = WebRTCService.factory.audioSource(with: audioConstraints)
        localAudioTrack = WebRTCService.factory.audioTrack(with: audioSource, trackId: "audio0")
        peerConnection?.add(localAudioTrack!, streamIds: ["stream0"])
        
        if isVideo {
            // Create video track
            let videoSource = WebRTCService.factory.videoSource()
            
            #if targetEnvironment(simulator)
            _ = RTCFileVideoCapturer(delegate: videoSource)
            #else
            videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
            setupVideoCapturer()
            #endif
            
            localVideoTrack = WebRTCService.factory.videoTrack(with: videoSource, trackId: "video0")
            peerConnection?.add(localVideoTrack!, streamIds: ["stream0"])
        }
    }
    
    private func setupVideoCapturer() {
        guard let capturer = videoCapturer else { 
            print("Video capturer is nil")
            return 
        }
        
        let devices = RTCCameraVideoCapturer.captureDevices()
        print("Available camera devices: \(devices.count)")
        
        guard let device = devices.first(where: {
            $0.position == .front
        }) else { 
            print("No front camera found, trying back camera")
            guard let backDevice = devices.first(where: { $0.position == .back }) else {
                print("No camera devices found")
                return
            }
            currentCaptureDevice = backDevice
            guard let format = RTCCameraVideoCapturer.supportedFormats(for: backDevice).first else { 
                print("No supported formats for back camera")
                return 
            }
            capturer.startCapture(with: backDevice, format: format, fps: 30)
            return
        }
        
        currentCaptureDevice = device
        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
        print("Available formats for front camera: \(formats.count)")
        
        guard let format = formats.first else { 
            print("No supported formats for front camera")
            return 
        }
        
        print("Starting video capture with format: \(format)")
        capturer.startCapture(with: device, format: format, fps: 30)
    }
    
    private func createDataChannel() {
        let config = RTCDataChannelConfiguration()
        guard let dataChannel = peerConnection?.dataChannel(
            forLabel: "data0",
            configuration: config
        ) else { return }
        
        localDataChannel = dataChannel
        localDataChannel?.delegate = self
    }
    
    private func createOffer() {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true",
                                 "OfferToReceiveVideo": "true"],
            optionalConstraints: nil
        )
        
        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let sdp = sdp else {
                print("Error creating offer: \(error?.localizedDescription ?? "")")
                return
            }
            
            self?.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    print("Error setting local description: \(error)")
                    return
                }
                
                Task {
                    try? await self?.signalingService.sendOffer(callId: self?.currentCallId ?? "", offer: sdp)
                }
            }
        }
    }
    
    func setLocalVideoView(_ view: RTCMTLVideoView) {
        localVideoView = view
        if let track = localVideoTrack {
            track.add(view)
            print("Local video track added to view")
        } else {
            print("No local video track available")
        }
    }
    
    func setRemoteVideoView(_ view: RTCMTLVideoView) {
        remoteVideoView = view
        if let track = remoteVideoTrack {
            track.add(view)
            print("Remote video track added to view")
        } else {
            print("No remote video track available")
        }
    }
    
    func setAudioEnabled(_ isEnabled: Bool) {
        localAudioTrack?.isEnabled = isEnabled
    }
    
    func setVideoEnabled(_ isEnabled: Bool) {
        localVideoTrack?.isEnabled = isEnabled
    }
    
    func addParticipantToCall(_ participant: String) {
        // Add participant to multi-call
        if !callParticipants.contains(participant) {
            callParticipants.append(participant)
            isMultiCall = callParticipants.count > 1
            
            // Notify Firebase about participant addition
            if let callId = currentCallId {
                Task {
                    // Add participant logic would go here
                    // This would require additional Firebase methods
                }
            }
        }
    }
    
    func removeParticipantFromCall(_ participant: String) {
        // Remove participant from multi-call
        callParticipants.removeAll { $0 == participant }
        isMultiCall = callParticipants.count > 1
        
        // Notify Firebase about participant removal
        if let callId = currentCallId {
            Task {
                // Remove participant logic would go here
                // This would require additional Firebase methods
            }
        }
    }
    
    func switchCamera() {
        guard let capturer = videoCapturer else { return }
        
        let currentPosition = currentCaptureDevice?.position
        let preferredPosition: AVCaptureDevice.Position = currentPosition == .front ? .back : .front
        
        guard let device = RTCCameraVideoCapturer.captureDevices().first(where: {
            $0.position == preferredPosition
        }) else { return }
        
        currentCaptureDevice = device
        guard let format = RTCCameraVideoCapturer.supportedFormats(for: device).first else { return }
        
        capturer.stopCapture {
            capturer.startCapture(with: device,
                                format: format,
                                fps: 30)
        }
    }
    
    func endCall() {
        // Prevent multiple calls to endCall
        guard !isEndingCall else { return }
        isEndingCall = true
        
        // End call in Supabase-backed signaling
        if let callId = currentCallId {
            Task {
                try? await signalingService.endCall(callId: callId)
            }
        }
        
        videoCapturer?.stopCapture()
        if let localView = localVideoView {
            localVideoTrack?.remove(localView)
        }
        if let remoteView = remoteVideoView {
            remoteVideoTrack?.remove(remoteView)
        }
        peerConnection?.close()
        
        localVideoTrack = nil
        remoteVideoTrack = nil
        localAudioTrack = nil
        remoteAudioTrack = nil
        localDataChannel = nil
        remoteDataChannel = nil
        peerConnection = nil
        
        // Reset state
        isInCall = false
        isInitiator = false
        currentTarget = nil
        currentCallId = nil
        callParticipants = []
        isMultiCall = false
        
        // Clean up audio session synchronously to avoid weak reference issues
        audioSession?.lockForConfiguration()
        try? audioSession?.setActive(false)
        audioSession?.unlockForConfiguration()
        
        // Notify delegate
        delegate?.webRTCService(self, didEndCall: nil)
    }
    
    deinit {
        // Only clean up if not already ending call
        if !isEndingCall {
            // Clean up resources synchronously in deinit
            videoCapturer?.stopCapture()
            peerConnection?.close()
            
            // Clean up audio session
            audioSession?.lockForConfiguration()
            try? audioSession?.setActive(false)
            audioSession?.unlockForConfiguration()
        }
    }
}

extension WebRTCService: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("Signaling state changed: \(stateChanged.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("Stream added with \(stream.videoTracks.count) video tracks and \(stream.audioTracks.count) audio tracks")
        
        if let videoTrack = stream.videoTracks.first {
            remoteVideoTrack = videoTrack
            print("Remote video track received")
            if let view = remoteVideoView {
                videoTrack.add(view)
                print("Remote video track added to view")
            } else {
                print("No remote video view available yet")
            }
            
            // Notify delegate
            delegate?.webRTCService(self, didReceiveRemoteVideoTrack: videoTrack)
        }
        
        if let audioTrack = stream.audioTracks.first {
            remoteAudioTrack = audioTrack
            print("Remote audio track received")
            
            // Notify delegate
            delegate?.webRTCService(self, didReceiveRemoteAudioTrack: audioTrack)
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
        
        // Notify delegate of connection state changes
        delegate?.webRTCService(self, didChangeConnectionState: newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("ICE gathering state changed: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Task {
            try? await signalingService.sendIceCandidate(callId: currentCallId ?? "", candidate: candidate)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("ICE candidates removed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("Data channel opened")
        remoteDataChannel = dataChannel
        remoteDataChannel?.delegate = self
    }
}

// Temporarily commented out due to linker issues
// extension WebRTCService: RTCVideoViewDelegate {
//     func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
//         // Handle video size changes
//     }
// }

extension WebRTCService: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("Data channel state changed: \(dataChannel.readyState.rawValue)")
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        if let message = String(data: buffer.data, encoding: .utf8) {
            print("Received message: \(message)")
        }
    }
}

extension WebRTCService: FirebaseSignalingDelegate {
    func firebaseSignaling(_ service: FirebaseSignalingService, didReceiveCallUpdate call: Call) {
        // Handle call updates
    }
    
    func firebaseSignaling(_ service: FirebaseSignalingService, didReceiveIncomingCall call: Call) {
        // Handle incoming calls
        handleIncomingCall(callId: call.id, from: call.callerId, isVideo: call.isVideo)
    }
    
    func firebaseSignaling(_ service: FirebaseSignalingService, didReceiveSignalingMessage message: SignalingMessage) {
        switch message.type {
        case .offer:
            if let sdp = message.sdp {
                let offer = RTCSessionDescription(type: .offer, sdp: sdp)
                handleOffer(offer)
            }
        case .answer:
            if let sdp = message.sdp {
                let answer = RTCSessionDescription(type: .answer, sdp: sdp)
                handleAnswer(answer)
            }
        case .iceCandidate:
            if let candidate = message.candidate,
               let sdpMLineIndex = message.sdpMLineIndex,
               let sdpMid = message.sdpMid {
                let iceCandidate = RTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                handleIceCandidate(iceCandidate)
            }
        case .callEnd:
            endCall()
        }
    }
    
    func firebaseSignaling(_ service: FirebaseSignalingService, didReceiveError error: Error) {
        delegate?.webRTCService(self, didReceiveError: error)
    }
    
    private func handleOffer(_ offer: RTCSessionDescription) {
        peerConnection?.setRemoteDescription(offer) { [weak self] error in
            if let error = error {
                print("Error setting remote description: \(error)")
                return
            }
            
            let constraints = RTCMediaConstraints(
                mandatoryConstraints: ["OfferToReceiveAudio": "true",
                                     "OfferToReceiveVideo": "true"],
                optionalConstraints: nil
            )
            
            self?.peerConnection?.answer(for: constraints) { sdp, error in
                guard let sdp = sdp else { return }
                
                self?.peerConnection?.setLocalDescription(sdp) { error in
                    if let error = error {
                        print("Error setting local description: \(error)")
                        return
                    }
                    
                    Task {
                        try? await self?.signalingService.sendAnswer(callId: self?.currentCallId ?? "", answer: sdp)
                    }
                }
            }
        }
    }
    
    private func handleAnswer(_ answer: RTCSessionDescription) {
        peerConnection?.setRemoteDescription(answer) { error in
            if let error = error {
                print("Error setting remote description: \(error)")
            }
        }
    }
    
    private func handleIceCandidate(_ candidate: RTCIceCandidate) {
        peerConnection?.add(candidate) { error in
            if let error = error {
                print("Error adding ICE candidate: \(error)")
            }
        }
    }
}

// MARK: - Note
// Signaling is handled by `FirebaseSignalingService` (Supabase-backed implementation).
