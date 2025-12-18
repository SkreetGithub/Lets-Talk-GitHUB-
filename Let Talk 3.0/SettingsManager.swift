import SwiftUI
import Combine
import Supabase

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var settings: AppSettings = AppSettings()
    @Published var isLoading = false
    @Published var error: Error?

    private let client = SupabaseManager.client

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        loadSettings()
        applyTheme(settings.theme)
    }

    // MARK: - Settings Management

    func loadSettings() {
        // Load from UserDefaults first
        if let data = UserDefaults.standard.data(forKey: "appSettings"),
           let savedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = savedSettings
        }

        // Then sync with Supabase if user is logged in
        if AuthManager.shared.isAuthenticated {
            Task { await syncWithSupabase() }
        }
    }

    func saveSettings() {
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "appSettings")
        }

        // Save to Supabase if user is logged in
        if AuthManager.shared.isAuthenticated {
            Task { await saveToSupabase() }
        }
    }

    private func syncWithSupabase() async {
        guard let userId = AuthManager.shared.currentUserId else { return }

        do {
            let response = try await client.from("profiles")
                .select("settings")
                .eq("id", value: userId)
                .single()
                .execute()

            let row = try decoder.decode(ProfileSettingsRow.self, from: response.data)
            if let remote = row.settings {
                await MainActor.run {
                    self.settings = self.mergeSettings(local: self.settings, remote: remote)
                }
            }
        } catch {
            // Non-fatal: keep local settings.
            await MainActor.run { self.error = error }
        }
    }

    private func saveToSupabase() async {
        guard let userId = AuthManager.shared.currentUserId else { return }

        do {
            let encoded = try JSONEncoder().encode(settings)
            let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] ?? [:]

            _ = try await client.from("profiles")
                .update(["settings": json])
                .eq("id", value: userId)
                .execute()
        } catch {
            await MainActor.run { self.error = error }
        }
    }

    private func mergeSettings(local: AppSettings, remote: AppSettings) -> AppSettings {
        // Remote wins for now.
        var merged = remote
        merged.lastUpdated = Date()
        return merged
    }

    // MARK: - Theme Management

    func setTheme(_ theme: AppTheme) {
        settings.theme = theme
        saveSettings()
        applyTheme(theme)
    }

    func setChatBubbleSentColor(_ color: ChatBubbleColor) {
        settings.chatBubbles.sentColor = color
        saveSettings()
    }

    func setChatBubbleReceivedColor(_ color: ChatBubbleColor) {
        settings.chatBubbles.receivedColor = color
        saveSettings()
    }

    func setCallInterfaceBackground(_ color: CallBackgroundColor) {
        settings.callInterface.background = color
        saveSettings()
    }

    private func applyTheme(_ theme: AppTheme) {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    switch theme {
                    case .light:
                        window.overrideUserInterfaceStyle = .light
                    case .dark:
                        window.overrideUserInterfaceStyle = .dark
                    case .system, .ocean, .sunset, .forest, .lavender, .fire, .arctic, .cosmic:
                        window.overrideUserInterfaceStyle = .unspecified
                    }
                }
            }
        }
    }

    // MARK: - Language Management

    func setLanguage(_ language: String) {
        settings.language = language
        saveSettings()
    }

    func setSourceLanguage(_ language: String) {
        settings.sourceLanguage = language
        saveSettings()
    }

    func setTargetLanguage(_ language: String) {
        settings.targetLanguage = language
        saveSettings()
    }

    // MARK: - Notification Settings

    func updateNotificationSettings(_ notifications: AppSettings.NotificationSettings) {
        settings.notifications = notifications
        saveSettings()
    }
    
    func setMessageNotifications(_ enabled: Bool) {
        settings.notifications.messages = enabled
        saveSettings()
    }
    
    func setCallNotifications(_ enabled: Bool) {
        settings.notifications.calls = enabled
        saveSettings()
    }
    
    func setTranslationNotifications(_ enabled: Bool) {
        settings.notifications.translations = enabled
        saveSettings()
    }
    
    func setPushNotifications(_ enabled: Bool) {
        settings.notifications.push = enabled
        saveSettings()
    }

    // MARK: - Privacy Settings

    func updatePrivacySettings(_ privacy: AppSettings.PrivacySettings) {
        settings.privacy = privacy
        saveSettings()
    }

    // MARK: - Audio Settings

    func updateAudioSettings(_ audio: AppSettings.AudioSettings) {
        settings.audio = audio
        saveSettings()
    }

    func setVolume(_ volume: Float) {
        settings.audio.volume = volume
        saveSettings()
    }
    
    func setVibration(_ enabled: Bool) {
        settings.audio.vibration = enabled
        saveSettings()
    }
    
    func setSpeakerMode(_ enabled: Bool) {
        settings.audio.speakerMode = enabled
        saveSettings()
    }

    // MARK: - Video Settings

    func updateVideoSettings(_ video: AppSettings.VideoSettings) {
        settings.video = video
        saveSettings()
    }
    
    func setVideoQuality(_ quality: VideoQuality) {
        settings.video.quality = quality
        saveSettings()
    }
    
    func setAutoStartVideo(_ enabled: Bool) {
        settings.video.autoStart = enabled
        saveSettings()
    }
    
    func setMirrorFrontCamera(_ enabled: Bool) {
        settings.video.mirrorFrontCamera = enabled
        saveSettings()
    }

    // MARK: - Translation Settings

    func updateTranslationSettings(_ translation: AppSettings.TranslationSettings) {
        settings.translation = translation
        saveSettings()
    }

    func setAutoTranslate(_ enabled: Bool) {
        settings.translation.autoTranslate = enabled
        saveSettings()
    }

    // MARK: - Reset Settings

    func resetToDefaults() {
        settings = AppSettings()
        saveSettings()
    }

    func exportSettings() -> Data? {
        try? JSONEncoder().encode(settings)
    }

    func importSettings(from data: Data) -> Bool {
        do {
            let imported = try JSONDecoder().decode(AppSettings.self, from: data)
            settings = imported
            saveSettings()
            return true
        } catch {
            return false
        }
    }
}

private struct ProfileSettingsRow: Codable {
    let settings: AppSettings?
}

// MARK: - App Settings Model

struct AppSettings: Codable {
    var theme: AppTheme = .system
    var language: String = "en"
    var sourceLanguage: String = "auto"
    var targetLanguage: String = "es"
    var notifications: NotificationSettings = NotificationSettings()
    var privacy: PrivacySettings = PrivacySettings()
    var audio: AudioSettings = AudioSettings()
    var video: VideoSettings = VideoSettings()
    var translation: TranslationSettings = TranslationSettings()
    var chatBubbles: ChatBubbleSettings = ChatBubbleSettings()
    var callInterface: CallInterfaceSettings = CallInterfaceSettings()
    var lastUpdated: Date = Date()

    struct NotificationSettings: Codable {
        var messages: Bool = true
        var calls: Bool = true
        var translations: Bool = true
        var push: Bool = true
    }

    struct PrivacySettings: Codable {
        var showOnlineStatus: Bool = true
        var allowCalls: Bool = true
        var allowMessages: Bool = true
        var shareLocation: Bool = false
    }

    struct AudioSettings: Codable {
        var volume: Float = 0.8
        var ringtone: String = "default"
        var vibration: Bool = true
        var speakerMode: Bool = false
    }

    struct VideoSettings: Codable {
        var quality: VideoQuality = .high
        var autoStart: Bool = false
        var mirrorFrontCamera: Bool = true
    }

    struct TranslationSettings: Codable {
        var autoTranslate: Bool = true
        var provider: TranslationProvider = .openAI
        var voiceEnabled: Bool = true
        var confidence: Float = 0.8
    }

    struct ChatBubbleSettings: Codable {
        var sentColor: ChatBubbleColor = .blue
        var receivedColor: ChatBubbleColor = .green
        var cornerRadius: Double = 16.0
        var fontSize: Double = 16.0
    }

    struct CallInterfaceSettings: Codable {
        var background: CallBackgroundColor = .dark
        var buttonColor: String = "blue"
        var textColor: String = "white"
        var showWaveform: Bool = true
    }

    init() {}
}

// MARK: - Enums

enum AppTheme: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    case ocean = "ocean"
    case sunset = "sunset"
    case forest = "forest"
    case lavender = "lavender"
    case fire = "fire"
    case arctic = "arctic"
    case cosmic = "cosmic"

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        case .lavender: return "Lavender"
        case .fire: return "Fire"
        case .arctic: return "Arctic"
        case .cosmic: return "Cosmic"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "gear"
        case .ocean: return "drop.fill"
        case .sunset: return "sunset.fill"
        case .forest: return "leaf.fill"
        case .lavender: return "sparkles"
        case .fire: return "flame.fill"
        case .arctic: return "snowflake"
        case .cosmic: return "star.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .light:
            return [Color.white, Color.gray.opacity(0.1)]
        case .dark:
            return [Color.black, Color.gray.opacity(0.3)]
        case .system:
            return [Color.primary, Color.secondary]
        case .ocean:
            return [Color.blue, Color.cyan, Color.teal]
        case .sunset:
            return [Color.orange, Color.pink, Color.purple]
        case .forest:
            return [Color.green, Color.mint, Color.teal]
        case .lavender:
            return [Color.purple, Color.pink, Color.blue]
        case .fire:
            return [Color.red, Color.orange, Color.yellow]
        case .arctic:
            return [Color.blue.opacity(0.8), Color.white, Color.cyan]
        case .cosmic:
            return [Color.purple, Color.indigo, Color.black]
        }
    }

    var isGradient: Bool {
        switch self {
        case .light, .dark, .system:
            return false
        default:
            return true
        }
    }
}

enum VideoQuality: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"

    var displayName: String {
        switch self {
        case .low: return "Low (240p)"
        case .medium: return "Medium (480p)"
        case .high: return "High (720p)"
        case .ultra: return "Ultra (1080p)"
        }
    }
}

enum TranslationProvider: String, CaseIterable, Codable {
    case google = "google"
    case openAI = "openAI"
    case azure = "azure"

    var displayName: String {
        switch self {
        case .google: return "Google Translate"
        case .openAI: return "OpenAI GPT"
        case .azure: return "Azure Translator"
        }
    }
}

enum ChatBubbleColor: String, CaseIterable, Codable {
    case blue = "blue"
    case green = "green"
    case purple = "purple"
    case orange = "orange"
    case red = "red"
    case pink = "pink"
    case teal = "teal"
    case indigo = "indigo"

    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        case .teal: return .teal
        case .indigo: return .indigo
        }
    }
}

enum CallBackgroundColor: String, CaseIterable, Codable {
    case dark = "dark"
    case light = "light"
    case blue = "blue"
    case purple = "purple"
    case green = "green"
    case red = "red"
    case orange = "orange"
    case pink = "pink"
    case teal = "teal"
    case indigo = "indigo"
    case mint = "mint"
    case yellow = "yellow"
    case gray = "gray"

    var color: Color {
        switch self {
        case .dark: return .black
        case .light: return .white
        case .blue: return .blue.opacity(0.8)
        case .purple: return .purple.opacity(0.8)
        case .green: return .green.opacity(0.8)
        case .red: return .red.opacity(0.8)
        case .orange: return .orange.opacity(0.8)
        case .pink: return .pink.opacity(0.8)
        case .teal: return .teal.opacity(0.8)
        case .indigo: return .indigo.opacity(0.8)
        case .mint: return .mint.opacity(0.8)
        case .yellow: return .yellow.opacity(0.8)
        case .gray: return .gray.opacity(0.8)
        }
    }

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .green: return "Green"
        case .red: return "Red"
        case .orange: return "Orange"
        case .pink: return "Pink"
        case .teal: return "Teal"
        case .indigo: return "Indigo"
        case .mint: return "Mint"
        case .yellow: return "Yellow"
        case .gray: return "Gray"
        }
    }
}
