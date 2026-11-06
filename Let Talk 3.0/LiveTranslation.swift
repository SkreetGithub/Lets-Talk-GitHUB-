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
    @Published var myLanguage: LiveLanguage = LiveLanguage.named(code: String(Locale.current.language.languageCode?.identifier ?? "en")) ?? LiveLanguage.all[0]
    @Published var peerLanguage: LiveLanguage?
    @Published var subtitle = ""            // what the other person said, in my language
    @Published var mySpeech = ""            // what I'm saying right now (original)
    @Published var detectedLanguageName: String?
    @Published var speakAloud = true
    @Published var errorMessage: String?

    private let recognizer = SpeechRecognizer()
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
    }

    // MARK: Lifecycle

    func start() {
        guard !isActive else { return }
        guard AIConsent.shared.requireConsent() else { return }
        isActive = true
        errorMessage = nil
        lastSent = ""
        sendPacket(Packet(type: "lang", lang: myLanguage.code, source: nil, original: nil, translated: nil))
        listen()
    }

    func stop() {
        isActive = false
        debounceTask?.cancel()
        recognizer.stopRecording()
        synthesizer.stopSpeaking(at: .immediate)
        mySpeech = ""
        subtitle = ""
        lastSent = ""
    }

    func changeMyLanguage(_ language: LiveLanguage) {
        myLanguage = language
        guard isActive else { return }
        recognizer.stopRecording()
        sendPacket(Packet(type: "lang", lang: language.code, source: nil, original: nil, translated: nil))
        listen()
    }

    // MARK: My speech -> translated -> peer

    private func listen() {
        recognizer.startRecording(language: myLanguage.locale) { [weak self] result in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                switch result {
                case .success(let text):
                    self.handlePartial(text)
                case .failure:
                    // The recognizer ends after silence/final result; restart while the call is active.
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    if self.isActive { self.listen() }
                }
            }
        }
    }

    private func handlePartial(_ text: String) {
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
            sendPacket(Packet(type: "subtitle", lang: target, source: myLanguage.code, original: chunk, translated: response.translatedText))
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
        case "subtitle":
            guard let text = packet.translated, !text.isEmpty else { return }
            if let source = packet.source, let lang = LiveLanguage.named(code: source) {
                detectedLanguageName = lang.name
            }
            subtitle = text
            scheduleSubtitleClear()
            if speakAloud { speak(text) }
        default:
            break
        }
    }

    private func speak(_ text: String) {
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
            Spacer()
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
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .transition(.opacity)
            }
            if !session.mySpeech.isEmpty {
                Text("You: \(session.mySpeech)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
                    .padding(.horizontal, 20)
            }
            Color.clear.frame(height: 150)   // keep clear of the call controls
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
