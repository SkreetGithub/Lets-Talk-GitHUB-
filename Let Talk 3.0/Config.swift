import Foundation
import CoreGraphics

enum Config {
    // MARK: - API Keys
    // NOTE: Do not hardcode secrets in source control. Populate these via `Info.plist`
    // (or an xcconfig that injects into Info.plist).
    static let openAIAPIKey = valueFromInfoPlist("OPENAI_API_KEY") ?? "YOUR_OPENAI_API_KEY"
    static let googleTranslateAPIKey = valueFromInfoPlist("GOOGLE_TRANSLATE_API_KEY") ?? "YOUR_GOOGLE_TRANSLATE_API_KEY"

    // MARK: - Supabase (replaces Firebase backend)
    static let supabaseURLString = valueFromInfoPlist("SUPABASE_URL") ?? "https://YOUR_PROJECT_REF.supabase.co"
    static let supabaseAnonKey = valueFromInfoPlist("SUPABASE_ANON_KEY") ?? "YOUR_SUPABASE_ANON_KEY"
    static let supabaseStorageBucket = valueFromInfoPlist("SUPABASE_STORAGE_BUCKET") ?? "public"

    static var supabaseURL: URL {
        guard let url = URL(string: supabaseURLString) else {
            preconditionFailure("Invalid SUPABASE_URL: \(supabaseURLString)")
        }
        return url
    }
    
    // WebRTC Configuration
    static let webRTCIceServers = [
        ["url": "stun:stun.l.google.com:19302"],
        ["url": "stun:stun1.l.google.com:19302"]
    ]
    
    // App Settings
    static let maxReconnectAttempts = 5
    static let reconnectDelay: TimeInterval = 3.0
    static let messagePageSize = 50
    static let maxImageSize = 1024 * 1024 * 5 // 5MB
    
    // Feature Flags
    static let enableVideoCall = true
    static let enableTranslation = true
    static let enableDynamicIsland = true
    
    // Cache Settings
    static let maxCacheSize = 100 * 1024 * 1024 // 100MB
    static let messageCacheTimeout: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // UI Constants
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let animationDuration: Double = 0.3
        
        static let colors = ThemeColors(
            primary: "007AFF",
            secondary: "5856D6",
            accent: "FF2D55",
            background: "F2F2F7",
            text: "000000"
        )
    }
}

struct ThemeColors {
    let primary: String
    let secondary: String
    let accent: String
    let background: String
    let text: String
}

private extension Config {
    static func valueFromInfoPlist(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
