import Foundation
import AVFoundation
import WebRTC

/// The call's microphone and speaker, owned by the app instead of WebRTC.
///
/// Why: WebRTC's built-in audio unit takes the microphone for itself, so live translation's
/// speech recognizer (a second AVAudioEngine) got a dead 0 Hz input and never heard a word.
/// Here ONE AVAudioEngine (with Apple's voice processing = echo cancellation) feeds the same
/// microphone audio to both WebRTC (the call) and the speech recognizer (`onMicrophoneBuffer`).
///
/// WebRTC drives it through `RTCAudioDevice`: it asks for recorded audio via `deliverRecordedData`
/// and pulls the other person's voice via `getPlayoutData`.
final class CallAudioDevice: NSObject, RTCAudioDevice {
    static let shared = CallAudioDevice()

    /// Called on a background queue with each microphone buffer (float, native format).
    /// Live translation's speech recognizer appends these while a call is running.
    var onMicrophoneBuffer: ((AVAudioPCMBuffer) -> Void)? {
        get { lock.withLock { _onMicrophoneBuffer } }
        set { lock.withLock { _onMicrophoneBuffer = newValue } }
    }
    private var _onMicrophoneBuffer: ((AVAudioPCMBuffer) -> Void)?

    /// 0...1 volume of the other person's voice. Lowered while their translation is spoken,
    /// so you hear the translation clearly over the original.
    var remoteVolume: Float {
        get { lock.withLock { _remoteVolume } }
        set { lock.withLock { _remoteVolume = max(0, min(1, newValue)) } }
    }
    private var _remoteVolume: Float = 1

    /// The format microphone buffers arrive in (valid while the engine runs).
    private(set) var microphoneFormat: AVAudioFormat?

    private let lock = NSLock()
    private let micQueue = DispatchQueue(label: "lettalk.callaudio.mic")
    /// Every engine build/stop runs here, one at a time (WebRTC, CallKit and route changes
    /// all ask from different threads).
    private let engineQueue = DispatchQueue(label: "lettalk.callaudio.engine")
    private var engine: AVAudioEngine?
    private var sinkNode: AVAudioSinkNode?
    private var sourceNode: AVAudioSourceNode?
    private weak var delegate: RTCAudioDeviceDelegate?
    private var configObserver: NSObjectProtocol?

    private var _isInitialized = false
    private var _isPlayoutInitialized = false
    private var _isRecordingInitialized = false
    private var _isPlaying = false
    private var _isRecording = false

    /// Scratch buffer for float -> int16 conversion on the audio thread (sized generously).
    private var int16Scratch = [Int16](repeating: 0, count: 8192)

    private var session: AVAudioSession { AVAudioSession.sharedInstance() }

    // MARK: - RTCAudioDevice properties

    var deviceInputSampleRate: Double {
        if let rate = microphoneFormat?.sampleRate, rate > 0 { return rate }
        return session.sampleRate > 0 ? session.sampleRate : 48_000
    }
    var inputIOBufferDuration: TimeInterval { session.ioBufferDuration }
    var inputNumberOfChannels: Int { 1 }
    var inputLatency: TimeInterval { session.inputLatency }
    var deviceOutputSampleRate: Double { session.sampleRate > 0 ? session.sampleRate : 48_000 }
    var outputIOBufferDuration: TimeInterval { session.ioBufferDuration }
    var outputNumberOfChannels: Int { 1 }
    var outputLatency: TimeInterval { session.outputLatency }

    var isInitialized: Bool { lock.withLock { _isInitialized } }
    var isPlayoutInitialized: Bool { lock.withLock { _isPlayoutInitialized } }
    var isRecordingInitialized: Bool { lock.withLock { _isRecordingInitialized } }
    var isPlaying: Bool { lock.withLock { _isPlaying } }
    var isRecording: Bool { lock.withLock { _isRecording } }

    // MARK: - Lifecycle

    func initialize(with delegate: RTCAudioDeviceDelegate) -> Bool {
        lock.withLock {
            self.delegate = delegate
            _isInitialized = true
        }
        return true
    }

    func terminateDevice() -> Bool {
        engineQueue.sync { stopEngine() }
        lock.withLock {
            _isInitialized = false
            _isPlayoutInitialized = false
            _isRecordingInitialized = false
            _isPlaying = false
            _isRecording = false
            delegate = nil
        }
        return true
    }

    func initializePlayout() -> Bool {
        lock.withLock { _isPlayoutInitialized = true }
        return true
    }

    func startPlayout() -> Bool {
        lock.withLock { _isPlaying = true }
        return startEngineIfNeeded()
    }

    func stopPlayout() -> Bool {
        let stop = lock.withLock { () -> Bool in
            _isPlaying = false
            return !_isRecording
        }
        if stop { engineQueue.sync { stopEngine() } }
        return true
    }

    func initializeRecording() -> Bool {
        lock.withLock { _isRecordingInitialized = true }
        return true
    }

    func startRecording() -> Bool {
        lock.withLock { _isRecording = true }
        return startEngineIfNeeded()
    }

    func stopRecording() -> Bool {
        let stop = lock.withLock { () -> Bool in
            _isRecording = false
            return !_isPlaying
        }
        if stop { engineQueue.sync { stopEngine() } }
        return true
    }

    // MARK: - Engine

    /// CallKit activated the audio session (call answered from the lock screen): the engine
    /// may have failed to start before that, so (re)start it now if the call wants audio.
    func audioSessionDidActivate() {
        let wanted = lock.withLock { _isPlaying || _isRecording }
        guard wanted else { return }
        engineQueue.async { _ = self.buildAndStartEngine() }
    }

    private func startEngineIfNeeded() -> Bool {
        engineQueue.sync {
            if let engine, engine.isRunning { return true }
            return buildAndStartEngine()
        }
    }

    private func buildAndStartEngine() -> Bool {
        stopEngine()
        let engine = AVAudioEngine()
        let input = engine.inputNode
        // Echo cancellation + noise suppression, like the Phone app. Not available on every
        // Simulator; the call still works without it.
        do { try input.setVoiceProcessingEnabled(true) } catch { debugLog("Voice processing unavailable:", error) }

        let micFormat = input.outputFormat(forBus: 0)
        guard micFormat.sampleRate > 0, micFormat.channelCount > 0 else {
            debugLog("CallAudioDevice: microphone not available yet")
            return false
        }
        let rateChanged = microphoneFormat?.sampleRate != micFormat.sampleRate
        microphoneFormat = micFormat

        // Microphone -> WebRTC (+ speech recognizer).
        let sink = AVAudioSinkNode { [weak self] timestamp, frameCount, inputData in
            self?.handleMicrophone(timestamp: timestamp, frameCount: frameCount, inputData: inputData, format: micFormat)
            return noErr
        }

        // WebRTC (the other person's voice) -> speaker. Int16 mono at the session rate.
        let rate = deviceOutputSampleRate
        guard let playFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: rate,
                                             channels: 1, interleaved: true) else { return false }
        let source = AVAudioSourceNode(format: playFormat) { [weak self] isSilence, timestamp, frameCount, outputData in
            self?.renderPlayout(isSilence: isSilence, timestamp: timestamp,
                                frameCount: frameCount, outputData: outputData) ?? noErr
        }

        engine.attach(sink)
        engine.attach(source)
        engine.connect(input, to: sink, format: micFormat)
        engine.connect(source, to: engine.mainMixerNode, format: playFormat)

        engine.prepare()
        do {
            try engine.start()
        } catch {
            debugLog("CallAudioDevice: engine failed to start:", error)
            return false
        }
        self.engine = engine
        self.sinkNode = sink
        self.sourceNode = source
        // WebRTC asked for the rate before the engine existed; tell it the real one.
        if rateChanged { delegate?.notifyAudioInputParametersChange() }

        // Route changes (speaker / Bluetooth / headphones) stop the engine: rebuild it.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let active = self.lock.withLock { self._isPlaying || self._isRecording }
            guard active else { return }
            self.delegate?.notifyAudioInputParametersChange()
            self.delegate?.notifyAudioOutputParametersChange()
            self.engineQueue.async { _ = self.buildAndStartEngine() }
        }
        return true
    }

    private func stopEngine() {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
        if let engine {
            engine.stop()
            if let sinkNode { engine.detach(sinkNode) }
            if let sourceNode { engine.detach(sourceNode) }
        }
        engine = nil
        sinkNode = nil
        sourceNode = nil
    }

    // MARK: - Audio thread

    private func handleMicrophone(timestamp: UnsafePointer<AudioTimeStamp>, frameCount: AVAudioFrameCount,
                                  inputData: UnsafePointer<AudioBufferList>, format: AVAudioFormat) {
        let frames = Int(frameCount)
        let abl = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
        guard frames > 0, let first = abl.first, let raw = first.mData else { return }

        // 1) Hand a MONO copy (channel 0) to the speech recognizer, off the audio thread.
        //    With voice processing on a real iPhone the mic format can have extra channels,
        //    which the recognizer doesn't accept.
        if let handler = onMicrophoneBuffer,
           let mono = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate,
                                    channels: 1, interleaved: false),
           let copy = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: frameCount),
           let dst = copy.floatChannelData?[0] {
            copy.frameLength = frameCount
            let src = raw.assumingMemoryBound(to: Float.self)
            let step = format.isInterleaved ? Int(format.channelCount) : 1
            for i in 0..<frames { dst[i] = src[i * step] }
            micQueue.async { handler(copy) }
        }

        // 2) Give WebRTC int16 mono (channel 0).
        let recording = lock.withLock { _isRecording }
        guard recording, let delegate = lock.withLock({ self.delegate }) else { return }
        if int16Scratch.count < frames { return }   // never allocate on the audio thread
        let floats = raw.assumingMemoryBound(to: Float.self)
        let stride = format.isInterleaved ? Int(format.channelCount) : 1
        for i in 0..<frames {
            let sample = max(-1, min(1, floats[i * stride]))
            int16Scratch[i] = Int16(sample * Float(Int16.max))
        }
        int16Scratch.withUnsafeMutableBytes { bytes in
            var list = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(frames * 2), mData: bytes.baseAddress)
            )
            var flags = AudioUnitRenderActionFlags()
            _ = delegate.deliverRecordedData(&flags, timestamp, 1, frameCount, &list, nil, nil)
        }
    }

    private func renderPlayout(isSilence: UnsafeMutablePointer<ObjCBool>, timestamp: UnsafePointer<AudioTimeStamp>,
                               frameCount: AVAudioFrameCount,
                               outputData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let abl = UnsafeMutableAudioBufferListPointer(outputData)
        let playing = lock.withLock { _isPlaying }
        guard playing, let delegate = lock.withLock({ self.delegate }) else {
            for buffer in abl { if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) } }
            isSilence.pointee = true
            return noErr
        }
        var flags = AudioUnitRenderActionFlags()
        let status = delegate.getPlayoutData(&flags, timestamp, 0, frameCount, outputData)
        let volume = remoteVolume
        if volume < 0.999, let data = abl.first?.mData {
            let samples = data.assumingMemoryBound(to: Int16.self)
            for i in 0..<Int(frameCount) { samples[i] = Int16(Float(samples[i]) * volume) }
        }
        return status
    }
}
