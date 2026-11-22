import SwiftUI
import UIKit

/// App-wide keyboard handling.
///
/// One tap recognizer sits on every window: a tap anywhere that isn't a text field closes the
/// keyboard. It never cancels or delays the tap, so the button you tapped still works.
/// Areas marked with `.keepsKeyboardOpen()` (the chat composer) are excluded, so tapping Send
/// doesn't close the keyboard between messages.
enum KeyboardDismisser {
    /// Closes the keyboard, wherever it is.
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private static var observer: NSObjectProtocol?

    /// Call once at launch. Covers windows created later too (sheets, the call window).
    static func install() {
        installOnAllWindows()
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { note in
            if let window = note.object as? UIWindow { install(on: window) }
        }
    }

    private static func installOnAllWindows() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.windows.forEach(install(on:))
        }
    }

    private static func install(on window: UIWindow) {
        guard !(window.gestureRecognizers ?? []).contains(where: { $0 is OutsideTapRecognizer }) else { return }
        let tap = OutsideTapRecognizer(target: OutsideTapHandler.shared, action: #selector(OutsideTapHandler.tapped(_:)))
        tap.cancelsTouchesInView = false     // the tapped button still gets its tap
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        tap.delegate = OutsideTapHandler.shared
        window.addGestureRecognizer(tap)
    }
}

private final class OutsideTapRecognizer: UITapGestureRecognizer {}

private final class OutsideTapHandler: NSObject, UIGestureRecognizerDelegate {
    static let shared = OutsideTapHandler()

    @objc func tapped(_ recognizer: UITapGestureRecognizer) {
        recognizer.view?.endEditing(true)
    }

    // Never block scrolling, swiping or any other gesture.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Tapping into a text field (or its clear button) must not close the keyboard.
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView || current is UISearchBar { return false }
            view = current.superview
        }
        // Areas that keep the keyboard open (chat composer).
        if let window = gestureRecognizer.view as? UIWindow {
            let point = touch.location(in: window)
            if KeepKeyboardZone.contains(point, in: window) { return false }
        }
        return true
    }
}

// MARK: - Areas that keep the keyboard open

private final class KeepKeyboardZone: UIView {
    private static let zones = NSHashTable<KeepKeyboardZone>.weakObjects()

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { Self.zones.add(self) } else { Self.zones.remove(self) }
    }

    static func contains(_ point: CGPoint, in window: UIWindow) -> Bool {
        zones.allObjects.contains { zone in
            zone.window === window && zone.convert(zone.bounds, to: window).contains(point)
        }
    }

    // Purely a marker: it never takes touches itself.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

private struct KeepKeyboardZoneView: UIViewRepresentable {
    func makeUIView(context: Context) -> KeepKeyboardZone {
        let view = KeepKeyboardZone()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: KeepKeyboardZone, context: Context) {}
}

extension View {
    /// Taps inside this view don't close the keyboard (used for the chat composer).
    func keepsKeyboardOpen() -> some View {
        background(KeepKeyboardZoneView())
    }
}
