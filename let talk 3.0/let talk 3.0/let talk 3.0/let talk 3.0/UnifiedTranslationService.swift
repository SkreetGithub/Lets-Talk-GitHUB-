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
class UnifiedTranslationViewModel: ObservableObject {
    @Published var sourceText = ""
    @Published var translatedText = ""
    @Published var sourceLanguage: UnifiedTranslationLanguage = .english
    @Published var targetLanguage: UnifiedTranslationLanguage = .spanish
    @Published var isTranslating = false
    @Published var isRecording = false
    @Published var isSpeakerOn = false
    @Published var isProcessingImage = false
    @Published var errorMessage = ""
    @Published var recentTranslations: [UnifiedTranslationHistory] = []
    @Published var favoriteTranslations: [UnifiedTranslationHistory] = []
    @Published var languagePresets: [LanguagePreset] = []
    
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let synthesizer = AVSpeechSynthesizer()
    
    init() {
        loadData()
        setupDefaultPresets()
    }
    
    var canTranslate: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTranslating
    }
    
    // MARK: - Translation Methods
    func translate() {
        guard canTranslate else { return }
        
        isTranslating = true
        errorMessage = ""
        
        // Simulate translation (replace with actual API call)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.translatedText = "Translated: \(self.sourceText)"
            self.isTranslating = false
            
            // Add to history
            let translation = UnifiedTranslationHistory(
                sourceText: self.sourceText,
                translatedText: self.translatedText,
                sourceLanguage: self.sourceLanguage,
                targetLanguage: self.targetLanguage
            )
            self.recentTranslations.insert(translation, at: 0)
            self.saveData()
        }
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
    }
    
    // MARK: - Voice Recognition
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition not available"
            return
        }
        
        isRecording = true
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session setup failed"
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Audio engine start failed"
            return
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.sourceText = result.bestTranscription.formattedString
                }
            }
            
            if error != nil {
                DispatchQueue.main.async {
                    self.isRecording = false
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                }
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        audioEngine.inputNode.removeTap(onBus: 0)
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    // MARK: - Text-to-Speech
    func toggleSpeaker() {
        if isSpeakerOn {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeakerOn = false
        } else if !translatedText.isEmpty {
            speakText(translatedText)
        }
    }
    
    private func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: targetLanguage.code)
        utterance.rate = 0.5
        
        synthesizer.speak(utterance)
        isSpeakerOn = true
    }
    
    // MARK: - Image Processing
    func processImage(_ image: UIImage) {
        isProcessingImage = true
        
        guard let cgImage = image.cgImage else {
            isProcessingImage = false
            return
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                isProcessingImage = false
                return
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            DispatchQueue.main.async {
                self.sourceText = recognizedText
                self.isProcessingImage = false
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Text recognition failed: \(error.localizedDescription)"
                self.isProcessingImage = false
            }
        }
    }
    
    // MARK: - Favorites
    func addToFavorites() {
        guard !sourceText.isEmpty && !translatedText.isEmpty else { return }
        
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
    }
}
