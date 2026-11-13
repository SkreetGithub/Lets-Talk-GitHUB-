import Foundation
import Speech
import AVFoundation

class TranslationService: ObservableObject {
    static let shared = TranslationService()
    
    private let speechRecognizer = SpeechRecognizer()
    private let synthesizer = AVSpeechSynthesizer()
    private let dataPersistence = DataPersistenceManager.shared
    
    private var audioSession: AVAudioSession?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var isTranslating = false
    @Published var translationHistory: [TranslationRecord] = []
    @Published var currentTranslation: TranslationRecord?
    
    init() {
        setupAudioSession()
        loadTranslationHistory()
    }
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .default)
            try audioSession?.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            debugLog("Failed to set up audio session: \(error)")
        }
    }
    
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String, useOpenAI: Bool = false) async throws -> TranslationResult {
        guard !text.isEmpty else { 
            return TranslationResult(originalText: text, translatedText: "", detectedLanguage: sourceLanguage, confidence: 0.0)
        }
        
        guard AIConsent.shared.requireConsent() else { throw TranslationError.consentRequired }

        isTranslating = true
        defer { isTranslating = false }
        
        do {
            let result: TranslationResult
            
            if useOpenAI {
                result = try await translateWithOpenAI(text: text, from: sourceLanguage, to: targetLanguage)
            } else {
                result = try await translateWithGoogle(text: text, from: sourceLanguage, to: targetLanguage)
            }
            
            // Save to history
            let record = TranslationRecord(
                id: UUID().uuidString,
                originalText: text,
                translatedText: result.translatedText,
                sourceLanguage: result.detectedLanguage,
                targetLanguage: targetLanguage,
                timestamp: Date(),
                confidence: result.confidence
            )
            
            await MainActor.run {
                translationHistory.insert(record, at: 0)
                currentTranslation = record
                saveTranslationHistory()
            }
            
            return result
        } catch {
            throw error
        }
    }
    
    private func translateWithGoogle(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> TranslationResult {
        try await translateViaBackend(text: text, from: sourceLanguage, to: targetLanguage, provider: "google", confidence: 0.9)
    }

    private func translateWithOpenAI(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> TranslationResult {
        try await translateViaBackend(text: text, from: sourceLanguage, to: targetLanguage, provider: "openai", confidence: 0.95)
    }

    /// All provider calls go through the `translate` Edge Function; no API keys exist in the app.
    private func translateViaBackend(text: String, from sourceLanguage: String, to targetLanguage: String, provider: String, confidence: Double) async throws -> TranslationResult {
        let source: String? = (sourceLanguage.isEmpty || sourceLanguage == "auto") ? nil : sourceLanguage
        let response = try await Backend.translate(text: text, source: source, target: targetLanguage, provider: provider)
        return TranslationResult(
            originalText: text,
            translatedText: response.translatedText,
            detectedLanguage: response.detectedLanguage ?? sourceLanguage,
            confidence: confidence
        )
    }

    private func getLanguageName(for code: String) -> String {
        let languageNames: [String: String] = [
            "en": "English",
            "es": "Spanish",
            "fr": "French",
            "de": "German",
            "it": "Italian",
            "pt": "Portuguese",
            "ru": "Russian",
            "ja": "Japanese",
            "ko": "Korean",
            "zh": "Chinese",
            "ar": "Arabic",
            "hi": "Hindi"
        ]
        return languageNames[code] ?? "English"
    }
    
    func startSpeechRecognition(language: String, completion: @escaping (Result<String, Error>) -> Void) {
        speechRecognizer.startRecording(language: language) { result in
            switch result {
            case .success(let text):
                completion(.success(text))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func stopSpeechRecognition() {
        speechRecognizer.stopRecording()
    }
    
    func speakText(_ text: String, language: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    // MARK: - Translation History Management
    private func saveTranslationHistory() {
        if let data = try? JSONEncoder().encode(translationHistory) {
            UserDefaults.standard.set(data, forKey: "translationHistory")
        }
        
        // Also cache in data persistence
        for translation in translationHistory {
            let cachedTranslation = CachedTranslation(
                id: translation.id,
                originalText: translation.originalText,
                translatedText: translation.translatedText,
                sourceLanguage: translation.sourceLanguage,
                targetLanguage: translation.targetLanguage,
                timestamp: translation.timestamp
            )
            dataPersistence.cacheTranslation(cachedTranslation)
        }
    }
    
    private func loadTranslationHistory() {
        if let data = UserDefaults.standard.data(forKey: "translationHistory"),
           let history = try? JSONDecoder().decode([TranslationRecord].self, from: data) {
            translationHistory = history
        }
    }
    
    func clearTranslationHistory() {
        translationHistory.removeAll()
        saveTranslationHistory()
    }
    
    // MARK: - Real-time Translation
    func startRealTimeTranslation(from sourceLanguage: String, to targetLanguage: String, completion: @escaping (TranslationResult) -> Void) {
        startSpeechRecognition(language: sourceLanguage) { [weak self] result in
            switch result {
            case .success(let recognizedText):
                Task {
                    do {
                        let translationResult = try await self?.translate(text: recognizedText, from: sourceLanguage, to: targetLanguage)
                        if let result = translationResult {
                            await MainActor.run {
                                completion(result)
                            }
                        }
                    } catch {
                        debugLog("Real-time translation error: \(error)")
                    }
                }
            case .failure(let error):
                debugLog("Speech recognition error: \(error)")
            }
        }
    }
    
    // MARK: - Language Detection
    func detectLanguage(_ text: String) -> String {
        // Simple language detection based on character patterns
        if text.range(of: "[¿¡ñáéíóúü]", options: .regularExpression) != nil { return "es" }
        if text.range(of: "[àâäéèêëïîôöùûüÿç]", options: .regularExpression) != nil { return "fr" }
        if text.range(of: "[äöüß]", options: .regularExpression) != nil { return "de" }
        if text.range(of: "[àèéìíîòóù]", options: .regularExpression) != nil { return "it" }
        if text.range(of: "[ãâáàçéêíóôõú]", options: .regularExpression) != nil { return "pt" }
        if text.range(of: "[а-яё]", options: .regularExpression) != nil { return "ru" }
        if text.range(of: "[ひらがなカタカナ漢字]", options: .regularExpression) != nil { return "ja" }
        if text.range(of: "[한글]", options: .regularExpression) != nil { return "ko" }
        if text.range(of: "[中文]", options: .regularExpression) != nil { return "zh" }
        if text.range(of: "[العربية]", options: .regularExpression) != nil { return "ar" }
        if text.range(of: "[हिन्दी]", options: .regularExpression) != nil { return "hi" }
        return "en"
    }
}

class SpeechRecognizer {
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var audioSession: AVAudioSession?
    private var completion: ((Result<String, Error>) -> Void)?
    
    func startRecording(language: String, completion: @escaping (Result<String, Error>) -> Void) {
        self.completion = completion
        
        // First check microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard granted else {
                Task { @MainActor in
                    completion(.failure(SpeechRecognitionError.notAuthorized))
                }
                return
            }
            
            // Then check speech recognition permission
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                guard status == .authorized else {
                    Task { @MainActor in
                        completion(.failure(SpeechRecognitionError.notAuthorized))
                    }
                    return
                }
                // AVAudioEngine setup must happen on the main thread.
                DispatchQueue.main.async {
                    self?.setupRecognition(language: language, completion: completion)
                }
            }
        }
    }
    
    private func setupRecognition(language: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Stop any existing recording first
        stopRecording()
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language))
        
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            Task { @MainActor in
                completion(.failure(SpeechRecognitionError.recognizerNotAvailable))
            }
            return
        }
        
        // Setup audio session. During a call WebRTC already owns a .playAndRecord/.voiceChat session:
        // leave it alone (switching mode/route here broke the call's audio). Only configure it when
        // nothing else has.
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            do {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                audioSession = session          // we activated it, so we deactivate it later
            } catch {
                Task { @MainActor in
                    completion(.failure(error))
                }
                return
            }
        } else {
            audioSession = nil                  // someone else (the call) owns the session
        }
        
        audioEngine = AVAudioEngine()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            Task { @MainActor in
                completion(.failure(SpeechRecognitionError.audioEngineError))
            }
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let error = error {
                Task { @MainActor in
                    completion(.failure(error))
                }
                self?.stopRecording()
                return
            }
            
            if let result = result {
                Task { @MainActor in
                    completion(.success(result.bestTranscription.formattedString))
                }
                
                if result.isFinal {
                    self?.stopRecording()
                }
            }
        }
        
        guard let inputNode = audioEngine?.inputNode else {
            Task { @MainActor in
                completion(.failure(SpeechRecognitionError.audioEngineError))
            }
            return
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        // With the mic held by the call, the input format can come back as 0 Hz / 0 channels.
        // installTap with that format raises an Objective-C exception and kills the app (the crash
        // seen when a call connected), so fail softly instead.
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            self.recognitionRequest = nil
            self.audioEngine = nil
            Task { @MainActor in
                completion(.failure(SpeechRecognitionError.audioEngineError))
            }
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        do {
            try audioEngine?.start()
        } catch {
            Task { @MainActor in
                completion(.failure(error))
            }
            stopRecording()
        }
    }
    
    func stopRecording() {
        // Stop audio engine safely
        if let audioEngine = audioEngine {
            if audioEngine.isRunning { audioEngine.stop() }
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // End recognition request
        recognitionRequest?.endAudio()
        
        // Cancel recognition task
        recognitionTask?.cancel()
        
        // Deactivate the audio session only if we activated it (never mid-call: that cut the call's audio).
        if let audioSession {
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                debugLog("Error deactivating audio session: \(error)")
            }
        }
        
        // Clear references
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        audioSession = nil
        completion = nil
    }
}

struct TranslationResponse: Codable {
    let data: TranslationData
}

struct TranslationData: Codable {
    let translations: [Translation]
}

struct Translation: Codable {
    let translatedText: String
}

enum TranslationError: Error {
    case invalidURL
    case serverError
    case invalidResponse
    case invalidImage
    case ocrFailed
    case networkError
    case consentRequired
}

enum SpeechRecognitionError: Error {
    case notAuthorized
    case recognizerNotAvailable
    case audioEngineError
}

extension TranslationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for translation request"
        case .serverError:
            return "Server error occurred during translation"
        case .invalidResponse:
            return "Invalid response from translation service"
        case .invalidImage:
            return "Invalid image provided"
        case .ocrFailed:
            return "Failed to extract text from image"
        case .networkError:
            return "Network error occurred"
        case .consentRequired:
            return "Please agree to translation data sharing first"
        }
    }
}

extension SpeechRecognitionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .recognizerNotAvailable:
            return "Speech recognizer not available for the selected language"
        case .audioEngineError:
            return "Error with audio engine"
        }
    }
}

// MARK: - Data Structures
struct TranslationResult {
    let originalText: String
    let translatedText: String
    let detectedLanguage: String
    let confidence: Double
}

struct TranslationRecord: Identifiable, Codable {
    let id: String
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date
    let confidence: Double
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct OpenAIMessage: Codable {
    let content: String
}
