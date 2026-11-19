import SwiftUI

/// The whole app's language (Settings › Language & Translation › My Language).
///
/// - SwiftUI text switches instantly: the app root (and the call window) set
///   `.environment(\.locale, …)`, and every `Text("…")` looks itself up in that language's
///   `<code>.lproj/Localizable.strings`.
/// - Text built in code (`L("…")`) reads the same files.
/// - iOS's own pieces (system alerts, keyboards) follow from the next launch (AppleLanguages).
/// - Arabic lays the app out right-to-left.
enum AppLanguage {
    /// Settings codes ("zh") -> the .lproj folder name ("zh-Hans").
    static func lprojName(for code: String) -> String {
        switch code {
        case "zh": return "zh-Hans"
        default: return code
        }
    }

    static var current: String { SettingsManager.shared.settings.language }

    static var locale: Locale { Locale(identifier: lprojName(for: current)) }

    static var layoutDirection: LayoutDirection { current == "ar" ? .rightToLeft : .leftToRight }

    private static var bundleCache: [String: Bundle] = [:]

    static func bundle(for code: String) -> Bundle {
        let name = lprojName(for: code)
        if let cached = bundleCache[name] { return cached }
        let bundle = Bundle.main.path(forResource: name, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        bundleCache[name] = bundle
        return bundle
    }

    /// Makes iOS use the same language for its own text from the next launch.
    static func applyToSystem(_ code: String) {
        UserDefaults.standard.set([lprojName(for: code)], forKey: "AppleLanguages")
    }
}

/// A UI string in the app's language (for text built in code, outside `Text("…")`).
func L(_ key: String) -> String {
    AppLanguage.bundle(for: AppLanguage.current).localizedString(forKey: key, value: key, table: nil)
}

extension View {
    /// Applies the app language (locale + right-to-left for Arabic) to a view tree.
    func appLanguage(_ code: String) -> some View {
        environment(\.locale, Locale(identifier: AppLanguage.lprojName(for: code)))
            .environment(\.layoutDirection, code == "ar" ? .rightToLeft : .leftToRight)
    }
}
