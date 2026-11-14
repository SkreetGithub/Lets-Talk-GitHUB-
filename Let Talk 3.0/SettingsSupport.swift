import SwiftUI
import UserNotifications

// Pieces shared by both Settings screens (Chats ⚙︎ and More › Settings), so they behave the same.

// MARK: - Push Notifications

/// "Push Notifications" switch that matches what iOS actually allows.
/// Turning it on asks for permission the first time; if the user denied it before, it explains
/// how to turn it on in the iOS Settings app (an app can't re-ask). Turning it off stops the
/// server from sending this account message and call notifications (it reads `notifications.push`).
struct PushNotificationsToggle: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var showDeniedAlert = false
    var title: String = "Push Notifications"

    var body: some View {
        Toggle(title, isOn: Binding(
            get: { settingsManager.settings.notifications.push },
            set: { on in on ? enable() : settingsManager.setPushNotifications(false) }
        ))
        .alert("Notifications Are Off", isPresented: $showDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Let Talk isn't allowed to send notifications. Turn on Notifications for Let Talk in the Settings app.")
        }
        .task { await syncWithSystem() }
    }

    private func enable() {
        Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            switch status {
            case .authorized, .provisional, .ephemeral:
                await turnOn()
            case .notDetermined:
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                if granted { await turnOn() } else { await MainActor.run { showDeniedAlert = true } }
            default:
                await MainActor.run { showDeniedAlert = true }
            }
        }
    }

    @MainActor private func turnOn() {
        settingsManager.setPushNotifications(true)
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// If iOS notifications were turned off in the Settings app, show the switch as off too.
    private func syncWithSystem() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if status == .denied, settingsManager.settings.notifications.push {
            await MainActor.run { settingsManager.setPushNotifications(false) }
        }
    }
}

// MARK: - AI Translation Consent

/// On/off for sending text to the translation providers (asked once on first use).
/// Stored on this iPhone; turning it off pauses translation until it's turned back on.
struct AITranslationConsentToggle: View {
    @ObservedObject private var consent = AIConsent.shared

    var body: some View {
        Toggle(isOn: Binding(
            get: { consent.hasConsented },
            set: { $0 ? consent.grant() : consent.revoke() }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Translation")
                Text(consent.hasConsented
                     ? "Text is sent to Google Translate / OpenAI to translate it."
                     : "Translation is paused. Turn on to translate calls and messages.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Blocked Users

/// Everyone you've blocked, with Unblock. (There was no way to see or undo a block before.)
struct BlockedUsersView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var moderation = ModerationManager.shared
    @State private var names: [String: String] = [:]
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && moderation.blockedIds.isEmpty {
                    ProgressView()
                } else if moderation.blockedIds.isEmpty {
                    ContentUnavailableView("No Blocked Users", systemImage: "hand.raised",
                                           description: Text("People you block can't call or message you. Block someone from the ••• menu in a chat."))
                } else {
                    List {
                        ForEach(moderation.blockedIds.sorted(), id: \.self) { userId in
                            HStack {
                                ProfileImageView(imageURL: nil, placeholderText: String((names[userId] ?? "?").prefix(1)))
                                    .frame(width: 36, height: 36)
                                Text(names[userId] ?? "Let Talk User")
                                Spacer()
                                Button("Unblock") {
                                    Task { await moderation.unblock(userId) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Blocked Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await moderation.refresh()
                isLoading = false
                for userId in moderation.blockedIds where names[userId] == nil {
                    if let user = try? await DatabaseManager.shared.getUser(id: userId) {
                        names[userId] = user.name
                    }
                }
            }
        }
    }
}

// MARK: - About

/// App version and build, plus how to get help.
struct AboutSection: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("\(version) (\(build))")
                    .foregroundColor(.secondary)
            }
            if let email = LegalURLs.supportEmail, let url = URL(string: "mailto:\(email)") {
                Link(destination: url) {
                    HStack {
                        Text("Contact Support")
                        Spacer()
                        Text(email).foregroundColor(.secondary)
                    }
                }
            }
            Link("Help & Support", destination: LegalURLs.support)
        } header: {
            Text("About")
        }
    }
}
