import SwiftUI

/// One spacing scale and corner radius for the whole app, so every screen uses the same layout math.
/// Colors and gradients are intentionally NOT here; the visual design stays per-screen.
enum DS {
    // MARK: Spacing (4-pt grid)
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: Corner radius
    static let cornerRadiusS: CGFloat = 12
    static let cornerRadiusM: CGFloat = 16
    static let cornerRadiusL: CGFloat = 20

    // MARK: Sizes
    /// Apple's minimum comfortable tap target.
    static let minTapTarget: CGFloat = 44
    /// Height for primary full-width buttons (Sign Up, Lock In, Continue).
    static let primaryButtonHeight: CGFloat = 52

    /// Space the floating tab bar (page dots + bar) covers at the bottom of every tab.
    static let floatingTabBarClearance: CGFloat = 120

    // MARK: Motion
    static let screenTransition = Animation.easeInOut(duration: 0.35)
    static let pressSpring = Animation.spring(duration: 0.2)
}
