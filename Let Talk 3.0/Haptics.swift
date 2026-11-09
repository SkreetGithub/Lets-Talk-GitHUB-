import UIKit

/// Small wrapper so views can fire haptics without each creating generators.
enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func tap()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
