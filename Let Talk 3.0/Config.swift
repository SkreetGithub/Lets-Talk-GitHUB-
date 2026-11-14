import Foundation
import CoreGraphics

enum Config {
    // MARK: - Third-party API keys
    // Google Translate / OpenAI keys are NOT in the app. They live in Supabase Edge Function secrets
    // (see supabase/functions). The app calls those functions via `Backend`.

    // MARK: - Supabase
    static let supabaseURLString = valueFromInfoPlist("SUPABASE_URL") ?? "https://YOUR_PROJECT_REF.supabase.co"
    static let supabaseAnonKey = valueFromInfoPlist("SUPABASE_ANON_KEY") ?? "YOUR_SUPABASE_ANON_KEY"
    static let supabaseStorageBucket = valueFromInfoPlist("SUPABASE_STORAGE_BUCKET") ?? "public"

    /// Where Supabase sends the user back after Sign in with Google. Must be listed in
    /// Supabase → Authentication → URL Configuration → Redirect URLs.
    static let authCallbackURL = URL(string: "lettalk://auth-callback")!

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
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unset xcconfig variable shows up as "$(NAME)"; treat that as missing.
        if trimmed.isEmpty || trimmed.hasPrefix("$(") { return nil }
        return trimmed
    }
}

/// Debug-only logging. Compiled out of Release builds so no tokens, transcripts, messages or phone numbers are ever logged.
@inline(__always)
func debugLog(_ items: Any...) {
    #if DEBUG
    print(items.map { "\($0)" }.joined(separator: " "))
    #endif
}
