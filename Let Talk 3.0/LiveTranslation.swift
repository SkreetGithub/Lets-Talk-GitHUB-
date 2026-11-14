import SwiftUI
import AVFoundation

/// Languages offered for live call translation.
struct LiveLanguage: Identifiable, Hashable {
    let code: String      // translation code, e.g. "es"
    let locale: String    // speech/TTS locale, e.g. "es-ES"
    let name: String
    var id: String { code }

    static let all: [LiveLanguage] = [
        .init(code: "en", locale: "en-US", name: "English"),
        .init(code: "es", locale: "es-ES", name: "Spanish"),
        .init(code: "fr", locale: "fr-FR", name: "French"),
        .init(code: "de", locale: "de-DE", name: "German"),
        .init(code: "it", locale: "it-IT", name: "Italian"),
        .init(code: "pt", locale: "pt-BR", name: "Portuguese"),
        .init(code: "ru", locale: "ru-RU", name: "Russian"),
        .init(code: "ja", locale: "ja-JP", name: "Japanese"),
        .init(code: "ko", locale: "ko-KR", name: "Korean"),
        .init(code: "zh", locale: "zh-CN", name: "Chinese"),
        .init(code: "ar", locale: "ar-SA", name: "Arabic"),
        .init(code: "hi", locale: "hi-IN", name: "Hindi")
    ]

    static func named(code: String) -> LiveLanguage? { all.first { $0.code == code } }
}

/// Live call translation: my speech -> streaming speech recognition -> server translation ->
/// sent to the other person over the WebRTC data channel -> shown as subtitles and spoken aloud
/// in their language.
@MainActor
final class LiveTranslationSession: ObservableObject {
    static let shared = LiveTranslationSession()

    @Published var isActive = false
    /// Starts from Settings → Language (the same language chat messages are translated into).
    @Published var myLanguage: LiveLanguage = LiveLanguage.named(code: SettingsManager.shared.settings.language)
        ?? LiveLanguage.named(code: String(Locale.current.language.languageCode?.identifier ?? "en"))
        ?? LiveLanguage.all[0]
    @Published var peerLanguage: LiveLanguage?
    @Published var subtitle = ""            // what the other person said, in my language
    @Published var mySpeech = ""            // what I'm saying right now (original)
    @Published var detectedLanguageName: String?
    @Published var speakAloud = true
    @Published var errorMessage: String?
    /// True while the call is muted: nothing I say is recognized, translated or sent.
    @Published private(set) var isMuted = false

    private let recognizer = SpeechRecognizer()
    private var consecutiveFailures = 0
    private let synthesizer = AVSpeechSynthesizer()
    private var debounceTask: Task<Void, Never>?
    private var lastSent = ""
    private var ignoreSpeechUntil = Date.distantPast
    private var subtitleClearTask: Task<Void, Never>?

    private struct Packet: Codable {
        let type: String        // "lang" | "subtitle"
        let lang: String?       // sender's language (for "lang") or the target language (for "subtitle")
        let source: String?
        let original: String?
        let translated: String?
        /// The sender's translation voice ("male-3"); the listener plays the translation in it.
        var voice: String? = nil
    }

    /// The other person's chosen voice (from their "lang" packet); nil = iPhone voice.
    private var peerVoiceId: String?
    private var myVoiceId: String? { AuthManager.shared.currentUser?.effectiveVoiceId }

    // MARK: Lifecycle

    func start() {
        guard !isActive else { return }
        guard AIConsent.shared.requireConsent() else { return }
        isActive = true
        isMuted = false
        errorMessage = nil
        lastSent = ""
        consecutiveFailures = 0
        sendPacket(Packet(type: "lang", lang: myLanguage.code, source: nil, original: nil, translated: nil, voice: myVoiceId))
        listen()
    }

    func stop() {
        isActive = false
        isMuted = false
        debounceTask?.cancel()
        recognizer.stopRecording()
        synthesizer.stopSpeaking(at: .immediate)
        TranslatedVoicePlayer.shared.stop()
        peerVoiceId = nil
        mySpeech = ""
        subtitle = ""
        lastSent = ""
    }

    /// Mute / unmute from the call screen (or the iPhone's call UI).
    /// Muting stops speech recognition and drops anything not yet sent; unmuting starts listening again.
    func setMuted(_ muted: Bool) {
        guard muted != isMuted else { return }
        isMuted = muted
        guard isActive else { return }
        if muted {
            debounceTask?.cancel()
            debounceTask = nil
            recognizer.stopRecording()
            mySpeech = ""
            lastSent = ""
        } else {
            lastSent = ""
            consecutiveFailures = 0
            listen()
        }
    }

    /// Picks up a language changed in Settings (only between calls; mid-call use changeMyLanguage).
    func adoptSavedLanguage() {
        guard !isActive, let saved = LiveLanguage.named(code: SettingsManager.shared.settings.language) else { return }
        myLanguage = saved
    }

    func changeMyLanguage(_ language: LiveLanguage) {
        myLanguage = language
        if SettingsManager.shared.settings.language != language.code {
            SettingsManager.shared.setLanguage(language.code)
        }
        guard isActive else { return }
        recognizer.stopRecording()
        sendPacket(Packet(type: "lang", lang: language.code, source: nil, original: nil, translated: nil, voice: myVoiceId))
        listen()
    }

    // MARK: My speech -> translated -> peer

    private func listen() {
        guard isActive, !isMuted else { return }
        recognizer.startRecording(language: myLanguage.locale) { [weak self] result in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                // Muted while the recognizer was still starting: switch the mic off again.
                if self.isMuted { self.recognizer.stopRecording(); return }
                switch result {
                case .success(let text):
                    self.consecutiveFailures = 0
                    self.handlePartial(text)
                case .failure(let error):
                    // The recognizer ends after silence/final result; restart while the call is active.
                    // Permission or microphone failures won't fix themselves, so back off instead of
                    // retrying every 0.4 s forever.
                    let hardFailure = (error as? SpeechRecognitionError).map {
                        $0 == .notAuthorized || $0 == .audioEngineError
                    } ?? false
                    if hardFailure {
                        self.consecutiveFailures += 1
                        if self.consecutiveFailures >= 3 {
                            self.errorMessage = "Live translation couldn't use the microphone."
                            return
                        }
                    }
                    try? await Task.sleep(nanoseconds: hardFailure ? 2_000_000_000 : 400_000_000)
                    if self.isActive && !self.isMuted { self.listen() }
                }
            }
        }
    }

    private func handlePartial(_ text: String) {
        guard !isMuted else { return }
        guard Date() >= ignoreSpeechUntil else { return }   // don't translate our own TTS echo
        mySpeech = text
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)     // ~0.7s of stable text
            guard !Task.isCancelled else { return }
            await self?.flush()
        }
    }

    private func flush() async {
        guard !isMuted else { return }
        let text = mySpeech.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != lastSent else { return }
        // Only send what's new since the last flush so we translate in short chunks (low latency).
        let chunk: String
        if text.hasPrefix(lastSent) {
            chunk = String(text.dropFirst(lastSent.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            chunk = text
        }
        lastSent = text
        guard !chunk.isEmpty, let target = peerLanguage?.code ?? defaultPeerCode() else { return }
        do {
            let response = try await Backend.translate(text: chunk, source: myLanguage.code, target: target)
            guard !isMuted, isActive else { return }   // muted while it was being translated
            sendPacket(Packet(type: "subtitle", lang: target, source: myLanguage.code, original: chunk,
                              translated: response.translatedText, voice: myVoiceId))
        } catch {
            errorMessage = "Translation is unavailable right now."
        }
    }

    private func defaultPeerCode() -> String? {
        // Until the other side tells us its language, translate to English (or Spanish if I'm English).
        myLanguage.code == "en" ? "es" : "en"
    }

    // MARK: Other person -> me

    func handleIncoming(_ data: Data) {
        guard let packet = try? JSONDecoder().decode(Packet.self, from: data) else { return }
        switch packet.type {
        case "lang":
            if let code = packet.lang, let lang = LiveLanguage.named(code: code) {
                peerLanguage = lang
                detectedLanguageName = lang.name
            }
            if let voice = packet.voice { peerVoiceId = voice }
        case "subtitle":
            guard let text = packet.translated, !text.isEmpty else { return }
            if let source = packet.source, let lang = LiveLanguage.named(code: source) {
                detectedLanguageName = lang.name
            }
            subtitle = text
            scheduleSubtitleClear()
            if speakAloud { speak(text, voiceId: packet.voice ?? peerVoiceId) }
        default:
            break
        }
    }

    /// Speaks the other person's translated words in THEIR chosen voice, in MY language
    /// (Google WaveNet via `speak`). Falls back to the iPhone's voice if they have no voice
    /// set or the server can't be reached, so a translation is never silently dropped.
    private func speak(_ text: String, voiceId: String?) {
        // Settings › Speak Translations in Calls off: captions only.
        guard SettingsManager.shared.settings.translation.voiceEnabled else { return }
        guard let voiceId else {
            speakWithDeviceVoice(text)
            return
        }
        // Block the mic right away; extended once the clip's real length is known.
        ignoreSpeechUntil = Date().addingTimeInterval(Double(text.count) * 0.08 + 0.8)
        Task { [weak self] in
            guard let self else { return }
            do {
                let duration = try await TranslatedVoicePlayer.shared.speak(text, voiceId: voiceId, language: self.myLanguage.code)
                self.ignoreSpeechUntil = max(self.ignoreSpeechUntil, Date().addingTimeInterval(duration + 0.5))
            } catch {
                debugLog("Translated voice unavailable, using device voice:", error)
                self.speakWithDeviceVoice(text)
            }
        }
    }

    private func speakWithDeviceVoice(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: myLanguage.locale)
        utterance.rate = 0.5
        // Ignore the microphone while the translated voice plays so it isn't re-translated.
        ignoreSpeechUntil = Date().addingTimeInterval(Double(text.count) * 0.08 + 0.8)
        synthesizer.speak(utterance)
    }

    private func scheduleSubtitleClear() {
        subtitleClearTask?.cancel()
        subtitleClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            self?.subtitle = ""
        }
    }

    private func sendPacket(_ packet: Packet) {
        guard let data = try? JSONEncoder().encode(packet) else { return }
        WebRTCCallManager.shared.sendData(data)
    }
}

// MARK: - UI

struct SubtitleOverlay: View {
    @ObservedObject var session: LiveTranslationSession

    var body: some View {
        VStack(spacing: 8) {
            if let message = session.errorMessage {
                Text(message).font(.caption).foregroundColor(.orange)
            }
            if !session.subtitle.isEmpty {
                Text(session.subtitle)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .lineLimit(4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Translated subtitle: \(session.subtitle)")
                    .transition(.opacity)
            }
            if !session.mySpeech.isEmpty {
                Text("You: \(session.mySpeech)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
                    .padding(.horizontal, 20)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.subtitle)
        .allowsHitTesting(false)
    }
}

struct LiveTranslationChip: View {
    @ObservedObject var session: LiveTranslationSession

    var body: some View {
        Menu {
            Section("I speak") {
                ForEach(LiveLanguage.all) { language in
                    Button(language.name) { session.changeMyLanguage(language) }
                }
            }
            Toggle("Speak translations aloud", isOn: $session.speakAloud)
            Button(session.isActive ? "Turn translation off" : "Turn translation on") {
                session.isActive ? session.stop() : session.start()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: session.isActive ? "captions.bubble.fill" : "captions.bubble")
                VStack(alignment: .leading, spacing: 0) {
                    Text(session.isActive ? "Translating" : "Translate").font(.caption.weight(.semibold))
                    if let detected = session.detectedLanguageName {
                        Text("Hearing: \(detected)").font(.caption2)
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .cornerRadius(10)
        }
    }
}
