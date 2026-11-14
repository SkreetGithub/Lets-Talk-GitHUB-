import SwiftUI
import Speech
import AVFoundation
import Vision
import VisionKit
import PhotosUI

// MARK: - Unified Translation Language
struct UnifiedTranslationLanguage: Identifiable, Equatable, Codable {
    let id = UUID()
    let code: String
    let name: String
    let flag: String
    let isPopular: Bool
    
    static let allLanguages: [UnifiedTranslationLanguage] = [
        // Popular languages
        UnifiedTranslationLanguage(code: "en", name: "English", flag: "🇺🇸", isPopular: true),
        UnifiedTranslationLanguage(code: "es", name: "Spanish", flag: "🇪🇸", isPopular: true),
        UnifiedTranslationLanguage(code: "fr", name: "French", flag: "🇫🇷", isPopular: true),
        UnifiedTranslationLanguage(code: "de", name: "German", flag: "🇩🇪", isPopular: true),
        UnifiedTranslationLanguage(code: "it", name: "Italian", flag: "🇮🇹", isPopular: true),
        UnifiedTranslationLanguage(code: "pt", name: "Portuguese", flag: "🇵🇹", isPopular: true),
        UnifiedTranslationLanguage(code: "ru", name: "Russian", flag: "🇷🇺", isPopular: true),
        UnifiedTranslationLanguage(code: "ja", name: "Japanese", flag: "🇯🇵", isPopular: true),
        UnifiedTranslationLanguage(code: "ko", name: "Korean", flag: "🇰🇷", isPopular: true),
        UnifiedTranslationLanguage(code: "zh", name: "Chinese", flag: "🇨🇳", isPopular: true),
        UnifiedTranslationLanguage(code: "ar", name: "Arabic", flag: "🇸🇦", isPopular: true),
        
        // Additional languages
        UnifiedTranslationLanguage(code: "hi", name: "Hindi", flag: "🇮🇳", isPopular: false),
        UnifiedTranslationLanguage(code: "nl", name: "Dutch", flag: "🇳🇱", isPopular: false),
        UnifiedTranslationLanguage(code: "sv", name: "Swedish", flag: "🇸🇪", isPopular: false),
        UnifiedTranslationLanguage(code: "no", name: "Norwegian", flag: "🇳🇴", isPopular: false),
        UnifiedTranslationLanguage(code: "da", name: "Danish", flag: "🇩🇰", isPopular: false),
        UnifiedTranslationLanguage(code: "fi", name: "Finnish", flag: "🇫🇮", isPopular: false),
        UnifiedTranslationLanguage(code: "pl", name: "Polish", flag: "🇵🇱", isPopular: false),
        UnifiedTranslationLanguage(code: "tr", name: "Turkish", flag: "🇹🇷", isPopular: false),
        UnifiedTranslationLanguage(code: "th", name: "Thai", flag: "🇹🇭", isPopular: false),
        UnifiedTranslationLanguage(code: "vi", name: "Vietnamese", flag: "🇻🇳", isPopular: false),
        UnifiedTranslationLanguage(code: "id", name: "Indonesian", flag: "🇮🇩", isPopular: false),
        UnifiedTranslationLanguage(code: "ms", name: "Malay", flag: "🇲🇾", isPopular: false),
        UnifiedTranslationLanguage(code: "tl", name: "Filipino", flag: "🇵🇭", isPopular: false),
        UnifiedTranslationLanguage(code: "he", name: "Hebrew", flag: "🇮🇱", isPopular: false),
        UnifiedTranslationLanguage(code: "uk", name: "Ukrainian", flag: "🇺🇦", isPopular: false),
        UnifiedTranslationLanguage(code: "cs", name: "Czech", flag: "🇨🇿", isPopular: false),
        UnifiedTranslationLanguage(code: "hu", name: "Hungarian", flag: "🇭🇺", isPopular: false),
        UnifiedTranslationLanguage(code: "ro", name: "Romanian", flag: "🇷🇴", isPopular: false),
        UnifiedTranslationLanguage(code: "bg", name: "Bulgarian", flag: "🇧🇬", isPopular: false),
        UnifiedTranslationLanguage(code: "hr", name: "Croatian", flag: "🇭🇷", isPopular: false),
        UnifiedTranslationLanguage(code: "sk", name: "Slovak", flag: "🇸🇰", isPopular: false),
        UnifiedTranslationLanguage(code: "sl", name: "Slovenian", flag: "🇸🇮", isPopular: false),
        UnifiedTranslationLanguage(code: "et", name: "Estonian", flag: "🇪🇪", isPopular: false),
        UnifiedTranslationLanguage(code: "lv", name: "Latvian", flag: "🇱🇻", isPopular: false),
        UnifiedTranslationLanguage(code: "lt", name: "Lithuanian", flag: "🇱🇹", isPopular: false),
        UnifiedTranslationLanguage(code: "el", name: "Greek", flag: "🇬🇷", isPopular: false),
        UnifiedTranslationLanguage(code: "is", name: "Icelandic", flag: "🇮🇸", isPopular: false),
        UnifiedTranslationLanguage(code: "ga", name: "Irish", flag: "🇮🇪", isPopular: false),
        UnifiedTranslationLanguage(code: "cy", name: "Welsh", flag: "🇬🇧", isPopular: false),
        UnifiedTranslationLanguage(code: "mt", name: "Maltese", flag: "🇲🇹", isPopular: false),
        UnifiedTranslationLanguage(code: "eu", name: "Basque", flag: "🇪🇸", isPopular: false),
        UnifiedTranslationLanguage(code: "ca", name: "Catalan", flag: "🇪🇸", isPopular: false),
        UnifiedTranslationLanguage(code: "gl", name: "Galician", flag: "🇪🇸", isPopular: false)
    ]
    
    static let english = allLanguages.first { $0.code == "en" }!
    static let spanish = allLanguages.first { $0.code == "es" }!
}

// MARK: - Translation History
struct UnifiedTranslationHistory: Identifiable, Codable {
    let id = UUID()
    let sourceText: String
    let translatedText: String
    let sourceLanguage: UnifiedTranslationLanguage
    let targetLanguage: UnifiedTranslationLanguage
    let timestamp: Date
    var isFavorite: Bool = false
    
    init(sourceText: String, translatedText: String, sourceLanguage: UnifiedTranslationLanguage, targetLanguage: UnifiedTranslationLanguage, timestamp: Date = Date(), isFavorite: Bool = false) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
        self.isFavorite = isFavorite
    }
}

// MARK: - Language Preset
struct LanguagePreset: Identifiable, Codable {
    let id = UUID()
    let name: String
    let sourceLanguage: UnifiedTranslationLanguage
    let targetLanguage: UnifiedTranslationLanguage
    let isDefault: Bool
    
    init(name: String, sourceLanguage: UnifiedTranslationLanguage, targetLanguage: UnifiedTranslationLanguage, isDefault: Bool = false) {
        self.name = name
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.isDefault = isDefault
    }
}

// MARK: - Unified Translation View Model
/// Drives the Translator tab. Translation runs on the server (`translate` Edge Function), speech
/// playback uses the user's WaveNet voice (`speak`), and dictation uses on-device speech recognition.
/// All @Published state is changed on the main thread.
class UnifiedTranslationViewModel: ObservableObject {
    @Published var sourceText = ""
    @Published var translatedText = ""
    @Published var sourceLanguage: UnifiedTranslationLanguage = .english {
        didSet { if oldValue.code != sourceLanguage.code { saveSelectedLanguages() } }
    }
    @Published var targetLanguage: UnifiedTranslationLanguage = .spanish {
        didSet { if oldValue.code != targetLanguage.code { saveSelectedLanguages() } }
    }
    @Published var isTranslating = false
    @Published var isRecording = false
    @Published var isSpeakerOn = false
    @Published var isProcessingImage = false
    /// Shown to the user as an alert when not empty.
    @Published var errorMessage = ""
    @Published var recentTranslations: [UnifiedTranslationHistory] = []
    @Published var favoriteTranslations: [UnifiedTranslationHistory] = []
    @Published var languagePresets: [LanguagePreset] = []
    /// How many times each language code was used in a translation (drives "Favorite Languages").
    @Published private(set) var languageUsage: [String: Int] = [:]
    /// Speak every new translation out loud automatically.
    @Published var autoSpeak: Bool = UserDefaults.standard.bool(forKey: "translatorAutoSpeak") {
        didSet { UserDefaults.standard.set(autoSpeak, forKey: "translatorAutoSpeak") }
    }
    
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let synthesizer = AVSpeechSynthesizer()
    private var speakTask: Task<Void, Never>?
    private var translateTask: Task<Void, Never>?
    
    private static let historyLimit = 100
    
    init() {
        loadData()
        setupDefaultPresets()
    }
    
    var canTranslate: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTranslating
    }
    
    /// The five languages used most, most-used first. Until there is enough history, the current
    /// pair and the most popular languages fill the remaining spots.
    var topLanguages: [UnifiedTranslationLanguage] {
        let used = languageUsage
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .compactMap { entry in UnifiedTranslationLanguage.allLanguages.first { $0.code == entry.key } }
        var result: [UnifiedTranslationLanguage] = []
        for language in used + [targetLanguage, sourceLanguage] + UnifiedTranslationLanguage.allLanguages.filter(\.isPopular)
        where !result.contains(where: { $0.code == language.code }) {
            result.append(language)
            if result.count == 5 { break }
        }
        return result
    }
    
    func usageCount(for language: UnifiedTranslationLanguage) -> Int {
        languageUsage[language.code] ?? 0
    }
    
    // MARK: - Translation
    
    func translate() {
        guard canTranslate else { return }
        if isRecording { stopRecording() }
        
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = sourceLanguage
        let target = targetLanguage
        
        isTranslating = true
        errorMessage = ""
        translateTask?.cancel()
        translateTask = Task { [weak self] in
            do {
                let response = try await Backend.translate(text: text, source: source.code, target: target.code)
                await self?.finishTranslation(response.translatedText, text: text, source: source, target: target)
            } catch is CancellationError {
                await self?.failTranslation(nil)
            } catch {
                await self?.failTranslation(error)
            }
        }
    }
    
    @MainActor private func finishTranslation(_ translated: String, text: String,
                                              source: UnifiedTranslationLanguage, target: UnifiedTranslationLanguage) {
        isTranslating = false
        translatedText = translated
        recordUsage(source: source, target: target)
        let entry = UnifiedTranslationHistory(
            sourceText: text,
            translatedText: translated,
            sourceLanguage: source,
            targetLanguage: target
        )
        recentTranslations.insert(entry, at: 0)
        if recentTranslations.count > Self.historyLimit {
            recentTranslations.removeLast(recentTranslations.count - Self.historyLimit)
        }
        saveData()
        if autoSpeak { speakTranslation() }
    }
    
    /// `error` is nil when the user cancelled.
    @MainActor private func failTranslation(_ error: Error?) {
        isTranslating = false
        if let error { errorMessage = Self.friendlyMessage(for: error, action: "translate") }
    }
    
    func swapLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
        
        if !sourceText.isEmpty && !translatedText.isEmpty {
            let tempText = sourceText
            sourceText = translatedText
            translatedText = tempText
        }
    }
    
    func clearSourceText() {
        sourceText = ""
        translatedText = ""
    }
    
    /// Makes `language` the "To" language (or "From", when it is already the "To" language).
    func useLanguage(_ language: UnifiedTranslationLanguage, asSource: Bool = false) {
        if asSource {
            if language.code == targetLanguage.code { targetLanguage = sourceLanguage }
            sourceLanguage = language
        } else {
            if language.code == sourceLanguage.code { sourceLanguage = targetLanguage }
            targetLanguage = language
        }
    }
    
    // MARK: - Voice input (speech to text)
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            requestSpeechPermissionsThenRecord()
        }
    }
    
    private func requestSpeechPermissionsThenRecord() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                guard status == .authorized else {
                    self.errorMessage = "Speech recognition is turned off for Let Talk. Turn it on in Settings › Let Talk › Speech Recognition."
                    return
                }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            self.errorMessage = "Microphone access is turned off for Let Talk. Turn it on in Settings › Let Talk › Microphone."
                            return
                        }
                        self.startRecording()
                    }
                }
            }
        }
    }
    
    private func startRecording() {
        stopSpeaking()
        guard let recognizer = Self.speechRecognizer(for: sourceLanguage), recognizer.isAvailable else {
            errorMessage = "Voice input isn't available for \(sourceLanguage.name) right now."
            return
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // playAndRecord (not .record) so the Speak button still works right after dictation.
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Couldn't start the microphone. Please try again."
            recognitionRequest = nil
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            recognitionRequest = nil
            errorMessage = "Couldn't start the microphone. Please try again."
            return
        }
        
        isRecording = true
        let textBefore = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    let spoken = result.bestTranscription.formattedString
                    self.sourceText = textBefore.isEmpty ? spoken : textBefore + " " + spoken
                    if result.isFinal { self.stopRecording() }
                }
                if error != nil, self.isRecording {
                    self.stopRecording()
                }
            }
        }
    }
    
    func stopRecording() {
        guard isRecording || recognitionTask != nil else { return }
        isRecording = false
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private static func speechRecognizer(for language: UnifiedTranslationLanguage) -> SFSpeechRecognizer? {
        let regions: [String: String] = [
            "en": "en-US", "es": "es-ES", "fr": "fr-FR", "de": "de-DE", "it": "it-IT", "pt": "pt-BR",
            "ru": "ru-RU", "ja": "ja-JP", "ko": "ko-KR", "zh": "zh-CN", "ar": "ar-SA", "hi": "hi-IN",
            "nl": "nl-NL", "sv": "sv-SE", "no": "nb-NO", "da": "da-DK", "fi": "fi-FI", "pl": "pl-PL",
            "tr": "tr-TR", "th": "th-TH", "vi": "vi-VN", "id": "id-ID", "ms": "ms-MY", "he": "he-IL",
            "uk": "uk-UA", "cs": "cs-CZ", "hu": "hu-HU", "ro": "ro-RO", "hr": "hr-HR", "sk": "sk-SK",
            "el": "el-GR", "ca": "ca-ES"
        ]
        let identifier = regions[language.code] ?? language.code
        return SFSpeechRecognizer(locale: Locale(identifier: identifier))
    }
    
    // MARK: - Speaker (text to speech)
    
    func toggleSpeaker() {
        if isSpeakerOn {
            stopSpeaking()
        } else {
            speakTranslation()
        }
    }
    
    /// Speaks the translation in the user's own Let Talk voice (Google WaveNet). Languages the
    /// voice service doesn't cover fall back to the iPhone's built-in voice.
    func speakTranslation() {
        let text = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "Translate something first, then tap Speak to hear it."
            return
        }
        if isRecording { stopRecording() }
        stopSpeaking()
        isSpeakerOn = true
        
        let language = targetLanguage
        let voiceId = AuthManager.shared.currentUser?.effectiveVoiceId ?? "female-1"
        speakTask = Task { [weak self] in
            do {
                let duration = try await TranslatedVoicePlayer.shared.speak(String(text.prefix(800)), voiceId: voiceId, language: language.code)
                try await Task.sleep(nanoseconds: UInt64(max(duration, 0.5) * 1_000_000_000))
                await self?.speakerFinished()
            } catch is CancellationError {
                // Stopped by the user.
            } catch {
                await self?.speakWithDeviceVoice(text, language: language)
            }
        }
    }
    
    @MainActor private func speakerFinished() {
        isSpeakerOn = false
    }
    
    func stopSpeaking() {
        speakTask?.cancel()
        speakTask = nil
        Task { @MainActor in TranslatedVoicePlayer.shared.stop() }
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isSpeakerOn = false
    }
    
    @MainActor private func speakWithDeviceVoice(_ text: String, language: UnifiedTranslationLanguage) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.code)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
        isSpeakerOn = true
        // Rough length of the utterance, so the button returns to "off" when speech ends.
        let seconds = max(1.5, Double(text.count) / 14)
        speakTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.deviceVoiceMayHaveFinished()
        }
    }
    
    @MainActor private func deviceVoiceMayHaveFinished() {
        if !synthesizer.isSpeaking { isSpeakerOn = false }
    }
    
    // MARK: - Text from images (scan / photo)
    
    func processImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            errorMessage = "Couldn't read that image."
            return
        }
        isProcessingImage = true
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        
        // Vision is slow on big photos: run it off the main thread so the screen doesn't freeze.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
                let text = (request.results ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isProcessingImage = false
                    if text.isEmpty {
                        self.errorMessage = "No text was found in that image. Try again with the text in focus."
                    } else {
                        self.sourceText = text
                        self.translatedText = ""
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isProcessingImage = false
                    self?.errorMessage = "Couldn't read text from that image. Please try again."
                }
            }
        }
    }
    
    // MARK: - Favorites
    
    var isCurrentTranslationFavorite: Bool {
        favoriteTranslations.contains { $0.sourceText == sourceText && $0.translatedText == translatedText }
    }
    
    /// Saves the current translation to Favorites, or removes it if it's already there.
    func addToFavorites() {
        guard !sourceText.isEmpty && !translatedText.isEmpty else { return }
        if let existing = favoriteTranslations.first(where: { $0.sourceText == sourceText && $0.translatedText == translatedText }) {
            removeFromFavorites(existing)
            return
        }
        let translation = UnifiedTranslationHistory(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            isFavorite: true
        )
        favoriteTranslations.insert(translation, at: 0)
        saveData()
    }
    
    func removeFromFavorites(_ translation: UnifiedTranslationHistory) {
        favoriteTranslations.removeAll { $0.id == translation.id }
        saveData()
    }
    
    /// Puts a saved or past translation back on the screen.
    func restore(_ translation: UnifiedTranslationHistory) {
        sourceLanguage = translation.sourceLanguage
        targetLanguage = translation.targetLanguage
        sourceText = translation.sourceText
        translatedText = translation.translatedText
    }
    
    func clearHistory() {
        recentTranslations.removeAll()
        saveData()
    }
    
    /// Adds translations from an exported file, skipping ones already in History. Returns how many were added.
    @discardableResult
    func importHistory(_ items: [UnifiedTranslationHistory]) -> Int {
        let fresh = items.filter { item in
            !recentTranslations.contains { $0.sourceText == item.sourceText && $0.translatedText == item.translatedText && $0.timestamp == item.timestamp }
        }
        guard !fresh.isEmpty else { return 0 }
        recentTranslations = (recentTranslations + fresh).sorted { $0.timestamp > $1.timestamp }
        if recentTranslations.count > Self.historyLimit {
            recentTranslations.removeLast(recentTranslations.count - Self.historyLimit)
        }
        saveData()
        return fresh.count
    }
    
    // MARK: - Language Presets
    private func setupDefaultPresets() {
        if languagePresets.isEmpty {
            languagePresets = [
                LanguagePreset(name: "English → Spanish", sourceLanguage: .english, targetLanguage: .spanish, isDefault: true),
                LanguagePreset(name: "Spanish → English", sourceLanguage: .spanish, targetLanguage: .english),
                LanguagePreset(name: "English → French", sourceLanguage: .english, targetLanguage: UnifiedTranslationLanguage.allLanguages.first { $0.code == "fr" }!),
                LanguagePreset(name: "English → German", sourceLanguage: .english, targetLanguage: UnifiedTranslationLanguage.allLanguages.first { $0.code == "de" }!),
                LanguagePreset(name: "English → Chinese", sourceLanguage: .english, targetLanguage: UnifiedTranslationLanguage.allLanguages.first { $0.code == "zh" }!)
            ]
        }
    }
    
    func addPreset(name: String, sourceLanguage: UnifiedTranslationLanguage, targetLanguage: UnifiedTranslationLanguage) {
        let preset = LanguagePreset(name: name, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        languagePresets.append(preset)
        saveData()
    }
    
    func removePreset(_ preset: LanguagePreset) {
        languagePresets.removeAll { $0.id == preset.id }
        saveData()
    }
    
    func applyPreset(_ preset: LanguagePreset) {
        sourceLanguage = preset.sourceLanguage
        targetLanguage = preset.targetLanguage
    }
    
    // MARK: - Helpers
    
    private func recordUsage(source: UnifiedTranslationLanguage, target: UnifiedTranslationLanguage) {
        // The language translated INTO counts double: it's the one people come back for.
        languageUsage[target.code, default: 0] += 2
        languageUsage[source.code, default: 0] += 1
        UserDefaults.standard.set(languageUsage, forKey: "translatorLanguageUsage")
    }
    
    private static func friendlyMessage(for error: Error, action: String) -> String {
        if let backend = error as? BackendError, case .notSignedIn = backend {
            return "Please sign in again to \(action)."
        }
        if (error as? URLError) != nil {
            return "Couldn't \(action) — check your internet connection and try again."
        }
        return "Couldn't \(action) right now. Please try again."
    }
    
    // MARK: - Data Persistence
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(recentTranslations) {
            UserDefaults.standard.set(encoded, forKey: "recentTranslations")
        }
        if let encoded = try? JSONEncoder().encode(favoriteTranslations) {
            UserDefaults.standard.set(encoded, forKey: "favoriteTranslations")
        }
        if let encoded = try? JSONEncoder().encode(languagePresets) {
            UserDefaults.standard.set(encoded, forKey: "languagePresets")
        }
    }
    
    private func saveSelectedLanguages() {
        UserDefaults.standard.set(sourceLanguage.code, forKey: "translatorSourceLanguage")
        UserDefaults.standard.set(targetLanguage.code, forKey: "translatorTargetLanguage")
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "recentTranslations"),
           let decoded = try? JSONDecoder().decode([UnifiedTranslationHistory].self, from: data) {
            recentTranslations = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "favoriteTranslations"),
           let decoded = try? JSONDecoder().decode([UnifiedTranslationHistory].self, from: data) {
            favoriteTranslations = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "languagePresets"),
           let decoded = try? JSONDecoder().decode([LanguagePreset].self, from: data) {
            languagePresets = decoded
        }
        if let usage = UserDefaults.standard.dictionary(forKey: "translatorLanguageUsage") as? [String: Int] {
            languageUsage = usage
        }
        // Reopen on the pair the user last chose.
        if let code = UserDefaults.standard.string(forKey: "translatorSourceLanguage"),
           let language = UnifiedTranslationLanguage.allLanguages.first(where: { $0.code == code }) {
            sourceLanguage = language
        }
        if let code = UserDefaults.standard.string(forKey: "translatorTargetLanguage"),
           let language = UnifiedTranslationLanguage.allLanguages.first(where: { $0.code == code }) {
            targetLanguage = language
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
