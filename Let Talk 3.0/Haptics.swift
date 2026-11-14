import UIKit

/// Small wrapper so views can fire haptics without each creating generators.
/// Respects Settings › Vibration (it was a switch that changed nothing).
enum Haptics {
    private static var enabled: Bool { SettingsManager.shared.settings.audio.vibration }
    static func success() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failure() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func warning() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func tap()     { guard enabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
