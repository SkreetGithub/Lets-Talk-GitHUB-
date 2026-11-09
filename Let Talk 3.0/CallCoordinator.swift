import Foundation
import Combine
import SwiftUI
import UIKit

/// The single entry point for calls.
///
/// Every call button (Chat, Contacts, Calls, Dial Pad, call-back) calls one of the `startCall`
/// methods here. Incoming calls detected by `WebRTCCallManager` are surfaced here too. Either way
/// the same `CallInterfaceView` is shown full screen in its own window above the app, so it
/// appears even while a sheet (Settings, a contact, New Chat) is open. A SwiftUI
/// `fullScreenCover` cannot be presented from a view that is already presenting a sheet.
///
/// Calls are addressed to a Let Talk **user ID**. Before this, buttons passed a phone number,
/// which the other phone never matched, so it never rang.
@MainActor
final class CallCoordinator: ObservableObject {
    static let shared = CallCoordinator()

    struct Presentation: Identifiable {
        let id: String
        let call: Call
        let isIncoming: Bool
    }

    /// Non-nil while the call screen should be on screen.
    @Published var presentation: Presentation? {
        didSet { updateCallWindow() }
    }
    /// Shown as an alert (e.g. "Jordan isn't on Let Talk yet.").
    @Published var errorMessage: String? {
        didSet { if let errorMessage { showAlert(errorMessage) } }
    }
    /// True while a phone number is being looked up.
    @Published var isResolving = false

    private let callManager = WebRTCCallManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var callWindow: UIWindow?
    private var alertWindow: UIWindow?

    private init() {
        callManager.$callStatus
            .combineLatest(callManager.$currentCall)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status, call in
                self?.callStateChanged(status: status, call: call)
            }
            .store(in: &cancellables)
    }

    // MARK: - Starting calls

    /// Call a Let Talk user directly (e.g. from a chat, where the other participant's ID is known).
    func startCall(toUserId userId: String, isVideo: Bool) {
        guard let me = AuthManager.shared.currentUserId else {
            errorMessage = CallError.userNotAuthenticated.localizedDescription
            return
        }
        guard userId != me else {
            errorMessage = CallError.cannotCallYourself.localizedDescription
            return
        }
        guard !callManager.isBusy else {
            errorMessage = CallError.alreadyInCall.localizedDescription
            return
        }

        // Show the call screen immediately ("Calling…"); the real call ID arrives a moment later.
        let pending = Call(id: UUID().uuidString, callerId: me, calleeId: userId, isVideo: isVideo,
                           status: .initiated, createdAt: Date(), participants: [me, userId])
        presentation = Presentation(id: pending.id, call: pending, isIncoming: false)
        Haptics.tap()

        Task {
            do {
                try await callManager.startCall(to: userId, isVideo: isVideo)
            } catch {
                presentation = nil
                errorMessage = error.localizedDescription
                Haptics.failure()
            }
        }
    }

    /// Call a phone number: looks up which Let Talk user owns it first.
    func startCall(toPhone phone: String, displayName: String? = nil, isVideo: Bool) {
        guard !isResolving else { return }
        isResolving = true
        Task {
            defer { isResolving = false }
            do {
                if let userId = try await DatabaseManager.shared.findUserId(byPhone: phone) {
                    startCall(toUserId: userId, isVideo: isVideo)
                } else {
                    errorMessage = CallError.notOnLetTalk(displayName ?? phone).localizedDescription
                    Haptics.failure()
                }
            } catch {
                errorMessage = CallError.networkError.localizedDescription
                Haptics.failure()
            }
        }
    }

    /// Call a saved contact. Contacts are address-book style entries, so resolve by phone.
    /// (Contacts built from a Let Talk profile carry the user ID and have no usable phone.)
    func startCall(to contact: Contact, isVideo: Bool) {
        if contact.phone.filter(\.isNumber).count >= 7 {
            startCall(toPhone: contact.phone, displayName: contact.name, isVideo: isVideo)
        } else if UUID(uuidString: contact.id) != nil {
            startCall(toUserId: contact.id.lowercased(), isVideo: isVideo)
        } else {
            errorMessage = CallError.notOnLetTalk(contact.name).localizedDescription
        }
    }

    // MARK: - Incoming / teardown

    private func callStateChanged(status: WebRTCCallStatus, call: Call?) {
        switch status {
        case .incoming:
            guard let call, presentation == nil else { return }
            presentation = Presentation(id: call.id, call: call, isIncoming: true)
            Haptics.warning()
        case .idle:
            // The call is over (ended, declined, missed or failed): close the call screen.
            presentation = nil
        default:
            break
        }
    }

    // MARK: - Call window

    private func updateCallWindow() {
        guard let presentation else {
            callWindow?.isHidden = true
            callWindow = nil
            return
        }
        guard let scene = activeScene() else { return }

        let root = CallInterfaceView(call: presentation.call, isIncoming: presentation.isIncoming)
            .environmentObject(AuthManager.shared)
            .environmentObject(SettingsManager.shared)
        let host = UIHostingController(rootView: AnyView(root))
        host.view.backgroundColor = .black

        let window = callWindow ?? UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = host
        window.makeKeyAndVisible()
        callWindow = window
    }

    /// Shows the error in its own window. Presenting on the top view controller failed silently
    /// when that controller was the dial pad sheet that had just started closing.
    private func showAlert(_ message: String) {
        guard let scene = activeScene() else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 2
        let host = UIViewController()
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.makeKeyAndVisible()
        alertWindow = window

        let alert = UIAlertController(title: "Can't Start Call", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel) { [weak self] _ in
            self?.errorMessage = nil
            self?.alertWindow?.isHidden = true
            self?.alertWindow = nil
        })
        host.present(alert, animated: true)
    }

    private func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
