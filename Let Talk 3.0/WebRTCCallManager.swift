import Foundation
import WebRTC
import AVFoundation

// MARK: - WebRTC Call Manager
//
// The ONE call engine. Every outgoing call (Chat, Contacts, Calls, Dial Pad) and every incoming
// call goes through here; `CallCoordinator` decides what is on screen. (`WebRTCService` no longer
// listens to signaling, so there is never a second peer connection fighting over the same call.)
//
// State is mutated on the main queue. WebRTC and signaling callbacks arrive on background
// threads and hop to main before touching anything.
final class WebRTCCallManager: NSObject, ObservableObject {
    static let shared = WebRTCCallManager()

    @Published var isInCall = false
    @Published var isVideoEnabled = true
    @Published var isAudioEnabled = true
    @Published var isSpeakerEnabled = false
    @Published var callStatus: WebRTCCallStatus = .idle
    @Published var currentCall: Call?
    @Published var connectionState: RTCIceConnectionState = .new

    /// How long an outgoing call rings before it is marked missed, and how long an incoming call
    /// shows before it is dismissed.
    private let ringTimeout: UInt64 = 45

    private var peerConnection: RTCPeerConnection?
    private var localVideoTrack: RTCVideoTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    private var videoCapturer: RTCCameraVideoCapturer?
    private var dataChannel: RTCDataChannel?
    private var usingFrontCamera = true

    // Video views can be registered before the tracks exist (the call screen appears first),
    // so keep them and attach as soon as each track arrives.
    private weak var localRenderer: RTCMTLVideoView?
    private weak var remoteRenderer: RTCMTLVideoView?

    // ICE candidates that arrive before the remote description is set must wait, or
    // RTCPeerConnection rejects them and the call never connects.
    private var pendingRemoteCandidates: [RTCIceCandidate] = []
    private var hasRemoteDescription = false

    /// Read from WebRTC's threads when sending ICE candidates; set before the peer connection exists.
    private var activeCallId: String?
    private var handledIncomingCallIds: Set<String> = []
    private var timeoutTask: Task<Void, Never>?

    private let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory()
        )
    }()

    private let signalingService = SupabaseSignalingService.shared

    override init() {
        super.init()
        // No audio-session activation here: doing it at launch stopped the user's music as soon
        // as the app opened. The session is configured when a call starts.
        signalingService.addDelegate(self)
        signalingService.startListeningForIncomingCalls()
    }

    /// True while a call is ringing, connecting or connected.
    var isBusy: Bool {
        switch callStatus {
        case .idle, .ended, .failed: return false
        default: return true
        }
    }

    // MARK: - Outgoing

    func startCall(to userId: String, isVideo: Bool = true) async throws {
        guard let me = AuthManager.shared.currentUserId else { throw CallError.userNotAuthenticated }
        let busy = await MainActor.run { isBusy }
        guard !busy else { throw CallError.alreadyInCall }

        await MainActor.run {
            resetCallState()
            isInCall = true
            isVideoEnabled = isVideo
            isSpeakerEnabled = isVideo          // video calls default to speaker, voice to earpiece
            callStatus = .initiating
        }
        configureAudioSession(speaker: isVideo || SettingsManager.shared.settings.audio.speakerMode)
        let configuration = await STUNTurnConfiguration.shared.makeConfiguration()

        do {
            let callId = try await signalingService.createCall(to: userId, isVideo: isVideo)
            activeCallId = callId
            await MainActor.run {
                currentCall = Call(id: callId, callerId: me, calleeId: userId, isVideo: isVideo,
                                   status: .initiated, createdAt: Date(), participants: [me, userId])
            }

            createPeerConnection(configuration)
            createMediaTracks(isVideo: isVideo)
            createDataChannel()                  // the caller opens the subtitle channel
            signalingService.listenForSignalingMessages(callId: callId)
            try await createOffer(callId: callId)

            startTimeout(callId: callId) { [weak self] in
                // Nobody answered: mark the call missed so the other phone stops ringing.
                try? await self?.signalingService.markMissed(callId: callId)
                await self?.finish(.ended)
            }
        } catch {
            await finish(.failed)
            throw error
        }
    }

    // MARK: - Incoming

    func answerCall(callId: String, isVideo: Bool = true) async throws {
        let alreadyActive = await MainActor.run { isInCall && activeCallId == callId }
        guard !alreadyActive else { return }

        cancelTimeout()
        activeCallId = callId
        await MainActor.run {
            isInCall = true
            isVideoEnabled = isVideo
            isSpeakerEnabled = isVideo
            callStatus = .answering
            if currentCall?.id != callId {
                // Answered from CallKit before the in-app poll saw the call.
                let me = AuthManager.shared.currentUserId ?? ""
                currentCall = Call(id: callId, callerId: "", calleeId: me, isVideo: isVideo,
                                   status: .answered, createdAt: Date(), participants: [me])
            }
        }
        configureAudioSession(speaker: isVideo || SettingsManager.shared.settings.audio.speakerMode)
        let configuration = await STUNTurnConfiguration.shared.makeConfiguration()

        // Peer connection first, so the caller's offer (already in call_signals) can be applied
        // the moment the signal poll delivers it.
        createPeerConnection(configuration)
        createMediaTracks(isVideo: isVideo)

        do {
            try await signalingService.answerCall(callId: callId, isVideo: isVideo)
            signalingService.listenForSignalingMessages(callId: callId)
            await MainActor.run {
                // "Connected" is only shown once ICE actually connects (it used to be set here).
                if callStatus == .answering { callStatus = .connecting }
            }
        } catch {
            await finish(.failed)
            throw error
        }
    }

    // MARK: - Hang up

    func endCall() async {
        let callId = await MainActor.run { () -> String? in
            guard isBusy || isInCall else { return nil }
            callStatus = .ending
            return currentCall?.id ?? activeCallId
        }
        guard let callId else { return }
        try? await signalingService.endCall(callId: callId)
        await finish(.ended)
    }

    func rejectCall() async {
        guard let callId = await MainActor.run(body: { currentCall?.id }) else { return }
        try? await signalingService.rejectCall(callId: callId)
        await finish(.ended)
    }

    /// Tears down media and returns to idle after a short pause, so the call screen can show
    /// "Call ended" / "Call failed" before it closes.
    private func finish(_ status: WebRTCCallStatus) async {
        cancelTimeout()
        if let id = activeCallId { signalingService.stopListening(callId: id) }
        cleanup()
        deactivateAudioSession()

        await MainActor.run {
            isInCall = false
            callStatus = status
            connectionState = .closed
        }
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        await MainActor.run {
            guard callStatus == status else { return }   // a new call already started
            callStatus = .idle
            currentCall = nil
            connectionState = .new
            activeCallId = nil
        }
    }

    // MARK: - Media Controls

    func toggleVideo() {
        isVideoEnabled.toggle()
        localVideoTrack?.isEnabled = isVideoEnabled
        if isVideoEnabled {
            startVideoCapture()
        } else {
            videoCapturer?.stopCapture()
        }
    }

    func toggleAudio() {
        isAudioEnabled.toggle()
        localAudioTrack?.isEnabled = isAudioEnabled
    }

    func toggleSpeaker() {
        isSpeakerEnabled.toggle()
        setSpeaker(isSpeakerEnabled)
    }

    func switchCamera() {
        guard let capturer = videoCapturer else { return }
        usingFrontCamera.toggle()
        guard let device = getCameraDevice(position: usingFrontCamera ? .front : .back),
              let format = getBestFormat(for: device) else { return }
        capturer.stopCapture {
            capturer.startCapture(with: device, format: format, fps: 30)
        }
    }

    // MARK: - Video Views

    func setLocalVideoView(_ view: RTCMTLVideoView) {
        DispatchQueue.main.async {
            self.localRenderer = view
            self.localVideoTrack?.add(view)
        }
    }

    func setRemoteVideoView(_ view: RTCMTLVideoView) {
        DispatchQueue.main.async {
            self.remoteRenderer = view
            self.remoteVideoTrack?.add(view)
        }
    }

    /// Sends a small payload (live-translation subtitles) to the other participant.
    func sendData(_ data: Data) {
        guard let channel = dataChannel, channel.readyState == .open else { return }
        channel.sendData(RTCDataBuffer(data: data, isBinary: false))
    }

    // MARK: - Peer connection

    private func createPeerConnection(_ configuration: RTCConfiguration) {
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection = factory.peerConnection(with: configuration, constraints: constraints, delegate: self)
    }

    private func createMediaTracks(isVideo: Bool) {
        let audioSource = factory.audioSource(with: nil)
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        localAudioTrack = audioTrack
        peerConnection?.add(audioTrack, streamIds: ["stream0"])

        guard isVideo else { return }
        let videoSource = factory.videoSource()
        videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        let videoTrack = factory.videoTrack(with: videoSource, trackId: "video0")
        localVideoTrack = videoTrack
        peerConnection?.add(videoTrack, streamIds: ["stream0"])
        startVideoCapture()   // no-op on the Simulator (no camera)

        DispatchQueue.main.async {
            if let renderer = self.localRenderer { videoTrack.add(renderer) }
        }
    }

    private func startVideoCapture() {
        guard let capturer = videoCapturer,
              let device = getCameraDevice(position: usingFrontCamera ? .front : .back)
                ?? getCameraDevice(position: .back),
              let format = getBestFormat(for: device) else { return }
        capturer.startCapture(with: device, format: format, fps: 30)
    }

    private func createDataChannel() {
        let config = RTCDataChannelConfiguration()
        config.isOrdered = true
        dataChannel = peerConnection?.dataChannel(forLabel: "subtitles", configuration: config)
        dataChannel?.delegate = self
    }

    private func offerAnswerConstraints() -> RTCMediaConstraints {
        RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"],
            optionalConstraints: nil
        )
    }

    private func createOffer(callId: String) async throws {
        guard let pc = peerConnection else { throw CallError.unknown }
        let sdp: RTCSessionDescription = try await withCheckedThrowingContinuation { continuation in
            pc.offer(for: offerAnswerConstraints()) { sdp, error in
                if let sdp { continuation.resume(returning: sdp) }
                else { continuation.resume(throwing: error ?? CallError.unknown) }
            }
        }
        try await setLocalDescription(sdp, on: pc)
        try await signalingService.sendOffer(callId: callId, offer: sdp)
    }

    private func createAnswer(callId: String) async throws {
        guard let pc = peerConnection else { throw CallError.unknown }
        let sdp: RTCSessionDescription = try await withCheckedThrowingContinuation { continuation in
            pc.answer(for: offerAnswerConstraints()) { sdp, error in
                if let sdp { continuation.resume(returning: sdp) }
                else { continuation.resume(throwing: error ?? CallError.unknown) }
            }
        }
        try await setLocalDescription(sdp, on: pc)
        try await signalingService.sendAnswer(callId: callId, answer: sdp)
    }

    private func setLocalDescription(_ sdp: RTCSessionDescription, on pc: RTCPeerConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pc.setLocalDescription(sdp) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    private func setRemoteDescription(_ sdp: RTCSessionDescription) async throws {
        guard let pc = peerConnection else { throw CallError.unknown }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pc.setRemoteDescription(sdp) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        // Now that the remote description is in place, apply candidates that arrived early.
        let queued: [RTCIceCandidate] = await MainActor.run {
            hasRemoteDescription = true
            defer { pendingRemoteCandidates.removeAll() }
            return pendingRemoteCandidates
        }
        for candidate in queued { pc.add(candidate) { _ in } }
    }

    // MARK: - Cleanup / state

    private func resetCallState() {
        pendingRemoteCandidates.removeAll()
        hasRemoteDescription = false
        remoteVideoTrack = nil
        connectionState = .new
        isAudioEnabled = true
        usingFrontCamera = true
    }

    private func cleanup() {
        videoCapturer?.stopCapture()
        dataChannel?.close()
        peerConnection?.close()

        localVideoTrack = nil
        remoteVideoTrack = nil
        localAudioTrack = nil
        remoteAudioTrack = nil
        dataChannel = nil
        peerConnection = nil
        videoCapturer = nil
        DispatchQueue.main.async {
            self.pendingRemoteCandidates.removeAll()
            self.hasRemoteDescription = false
        }
    }

    // MARK: - Timeouts

    private func startTimeout(callId: String, onTimeout: @escaping () async -> Void) {
        cancelTimeout()
        let seconds = ringTimeout
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled, let self else { return }
            let stillRinging = await MainActor.run {
                self.activeCallId == callId
                    && (self.callStatus == .initiating || self.callStatus == .incoming)
            }
            if stillRinging { await onTimeout() }
        }
    }

    private func cancelTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    // MARK: - Audio session (only active during a call)

    private func configureAudioSession(speaker: Bool) {
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.lockForConfiguration()
        defer { rtcSession.unlockForConfiguration() }
        do {
            let session = rtcSession.session
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
            try session.overrideOutputAudioPort(speaker ? .speaker : .none)
        } catch {
            debugLog("Audio session setup failed: \(error)")
        }
    }

    private func setSpeaker(_ on: Bool) {
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.lockForConfiguration()
        defer { rtcSession.unlockForConfiguration() }
        do {
            try rtcSession.session.overrideOutputAudioPort(on ? .speaker : .none)
        } catch {
            debugLog("Error toggling speaker: \(error)")
        }
    }

    private func deactivateAudioSession() {
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.lockForConfiguration()
        defer { rtcSession.unlockForConfiguration() }
        // Lets the user's music resume after the call.
        try? rtcSession.session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Camera Helpers

    private func getCameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        RTCCameraVideoCapturer.captureDevices().first { $0.position == position }
    }

    /// A 720p-ish format at 30 fps; the old code took the first (lowest) format.
    private func getBestFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
        let target: Int32 = 1280
        return formats
            .filter { format in format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 30 } }
            .min { a, b in
                abs(CMVideoFormatDescriptionGetDimensions(a.formatDescription).width - target)
                    < abs(CMVideoFormatDescriptionGetDimensions(b.formatDescription).width - target)
            } ?? formats.last
    }

    // MARK: - Remote media

    private func attachRemoteVideo(_ track: RTCVideoTrack) {
        DispatchQueue.main.async {
            guard self.remoteVideoTrack !== track else { return }
            self.remoteVideoTrack = track
            if let renderer = self.remoteRenderer { track.add(renderer) }
        }
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCCallManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        debugLog("Signaling state changed: \(stateChanged.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if let videoTrack = stream.videoTracks.first { attachRemoteVideo(videoTrack) }
        if let audioTrack = stream.audioTracks.first { remoteAudioTrack = audioTrack }
    }

    /// Unified Plan delivers remote tracks here.
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        if let videoTrack = rtpReceiver.track as? RTCVideoTrack { attachRemoteVideo(videoTrack) }
        if let audioTrack = rtpReceiver.track as? RTCAudioTrack { remoteAudioTrack = audioTrack }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        debugLog("ICE connection state changed: \(newState.rawValue)")
        DispatchQueue.main.async {
            self.connectionState = newState
            switch newState {
            case .connected, .completed:
                if self.callStatus != .ending { self.callStatus = .connected }
            case .disconnected:
                // Often recovers by itself (network switch); show it but don't end the call.
                if self.callStatus == .connected { self.callStatus = .disconnected }
            case .failed:
                // ICE could not find any path (typically no TURN on a strict NAT).
                Task { await self.finish(.failed) }
            default:
                break
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        guard let callId = activeCallId else { return }
        Task {
            try? await signalingService.sendIceCandidate(callId: callId, candidate: candidate)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        // The callee receives the subtitle channel the caller created.
        dataChannel.delegate = self
        self.dataChannel = dataChannel
    }
}

// MARK: - RTCDataChannelDelegate

extension WebRTCCallManager: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        debugLog("Data channel state changed: \(dataChannel.readyState.rawValue)")
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        let data = buffer.data
        Task { @MainActor in
            LiveTranslationSession.shared.handleIncoming(data)
        }
    }
}

// MARK: - SupabaseSignalingDelegate

extension WebRTCCallManager: SupabaseSignalingDelegate {
    func supabaseSignaling(_ service: SupabaseSignalingService, didReceiveIncomingCall call: Call) {
        DispatchQueue.main.async {
            // Ignore while busy, and never re-ring a call we've already shown.
            guard !self.isBusy, !self.handledIncomingCallIds.contains(call.id) else { return }
            self.handledIncomingCallIds.insert(call.id)
            self.resetCallState()
            self.activeCallId = call.id
            self.currentCall = call
            self.callStatus = .incoming
            // Watch the call row so we stop ringing if the caller hangs up first.
            self.signalingService.watchCall(callId: call.id)
            self.startTimeout(callId: call.id) { [weak self] in
                await self?.finish(.ended)
            }
        }
    }

    func supabaseSignaling(_ service: SupabaseSignalingService, didReceiveCallUpdate call: Call) {
        DispatchQueue.main.async {
            guard call.id == self.activeCallId else { return }
            switch call.status {
            case .rejected, .ended, .missed:
                // The other side declined, hung up, or the ring timed out.
                guard self.callStatus != .ending, self.isBusy || self.isInCall else { return }
                Task { await self.finish(.ended) }
            case .answered:
                if self.callStatus == .initiating {
                    self.cancelTimeout()
                    self.callStatus = .connecting
                }
            default:
                break
            }
        }
    }

    func supabaseSignaling(_ service: SupabaseSignalingService, didReceiveSignalingMessage message: SignalingMessage) {
        DispatchQueue.main.async {
            guard message.callId == self.activeCallId else { return }
            switch message.type {
            case .offer:
                guard let sdp = message.sdp, !self.hasRemoteDescription else { return }
                let callId = message.callId
                Task {
                    do {
                        try await self.setRemoteDescription(RTCSessionDescription(type: .offer, sdp: sdp))
                        try await self.createAnswer(callId: callId)
                    } catch {
                        debugLog("Answering offer failed: \(error)")
                        await self.finish(.failed)
                    }
                }
            case .answer:
                guard let sdp = message.sdp, !self.hasRemoteDescription else { return }
                Task {
                    do {
                        try await self.setRemoteDescription(RTCSessionDescription(type: .answer, sdp: sdp))
                    } catch {
                        debugLog("Applying answer failed: \(error)")
                        await self.finish(.failed)
                    }
                }
            case .iceCandidate:
                guard let candidate = message.candidate,
                      let index = message.sdpMLineIndex else { return }
                let ice = RTCIceCandidate(sdp: candidate, sdpMLineIndex: index, sdpMid: message.sdpMid)
                if self.hasRemoteDescription, let pc = self.peerConnection {
                    pc.add(ice) { error in
                        if let error { debugLog("Error adding ICE candidate: \(error)") }
                    }
                } else {
                    self.pendingRemoteCandidates.append(ice)
                }
            case .callEnd:
                Task { await self.finish(.ended) }
            }
        }
    }

    func supabaseSignaling(_ service: SupabaseSignalingService, didReceiveError error: Error) {
        // Polling errors are usually transient (a dropped request); the next poll retries.
        // They used to set callStatus = .failed and kill the call.
        debugLog("Signaling error: \(error)")
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
    case notOnLetTalk(String)
    case cannotCallYourself
    case unknown

    var errorDescription: String? {
        switch self {
        case .alreadyInCall:
            return "You're already in a call."
        case .userNotAuthenticated:
            return "Please sign in again."
        case .networkError:
            return "Network error. Check your connection and try again."
        case .notOnLetTalk(let who):
            return "\(who) isn't on Let Talk yet."
        case .cannotCallYourself:
            return "You can't call your own number."
        case .unknown:
            return "The call couldn't be started."
        }
    }
}
