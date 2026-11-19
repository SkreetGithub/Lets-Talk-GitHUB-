import SwiftUI

// The second level of Settings. The main Settings screen is now a short menu of rows with
// arrows (like the iPhone's Settings app); every detailed option lives on one of these pages.

/// A Settings menu row: colored icon tile + title (+ optional value) + system chevron.
/// A row that opens a full settings screen as a sheet (screens that have their own Done button).
struct SettingsSheetRow<Destination: View, RowLabel: View>: View {
    @ViewBuilder let destination: () -> Destination
    @ViewBuilder let label: () -> RowLabel
    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: {
            HStack {
                label().foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .sheet(isPresented: $isPresented) { destination() }
    }
}

struct SettingsMenuRow: View {
    let title: String
    let icon: String
    let color: Color
    var value: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color))
                .accessibilityHidden(true)
            Text(title)
            Spacer()
            if let value {
                Text(value).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Appearance

struct AppearanceSettingsPage: View {
    @ObservedObject private var settingsManager = SettingsManager.shared

    var body: some View {
        List {
            Section {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button {
                        settingsManager.setTheme(theme)
                        Haptics.tap()
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(LinearGradient(colors: theme.isGradient ? theme.gradientColors : [theme.accent, theme.accent.opacity(0.7)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 26, height: 26)
                                .overlay(Image(systemName: theme.icon).font(.system(size: 11, weight: .bold)).foregroundStyle(.white))
                            Text(theme.displayName).foregroundStyle(.primary)
                            Spacer()
                            if settingsManager.settings.theme == theme {
                                Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } header: {
                Text("Theme")
            } footer: {
                Text("Light and Dark change the whole app. Color themes also change buttons, switches and the tab bar.")
            }

            Section {
                SettingsSheetRow {
                    ChatStyleSettingsView()
                } label: {
                    SettingsMenuRow(title: "Chat & Call Style", icon: "bubble.left.and.bubble.right.fill", color: .blue)
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Language & Translation

struct LanguageTranslationSettingsPage: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject var translationViewModel: UnifiedTranslationViewModel
    @State private var showPresets = false

    static let languages: [(code: String, name: String)] = [
        ("en", "English"), ("es", "Español"), ("fr", "Français"), ("de", "Deutsch"),
        ("it", "Italiano"), ("pt", "Português"), ("ru", "Русский"), ("ja", "日本語"),
        ("ko", "한국어"), ("zh", "中文"), ("ar", "العربية"), ("hi", "हिन्दी")
    ]

    var body: some View {
        List {
            Section {
                Picker(selection: Binding(
                    get: { settingsManager.settings.language },
                    set: { settingsManager.setLanguage($0) }
                )) {
                    ForEach(Self.languages, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                } label: {
                    Label("My Language", systemImage: "globe.americas.fill")
                }
            } footer: {
                Text("The app, your messages and your calls switch to this language.")
            }

            Section("Translation") {
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.translation.autoTranslate },
                    set: { settingsManager.setAutoTranslate($0) }
                )) {
                    Label("Auto-translate Messages", systemImage: "text.bubble.fill")
                }
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.translation.voiceEnabled },
                    set: { settingsManager.setVoiceEnabled($0) }
                )) {
                    Label("Speak Translations in Calls", systemImage: "speaker.wave.2.bubble.fill")
                }
                Picker(selection: Binding(
                    get: { settingsManager.settings.translation.provider },
                    set: { settingsManager.setTranslationProvider($0) }
                )) {
                    ForEach(TranslationProvider.available, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                } label: {
                    Label("Translation Quality", systemImage: "sparkles")
                }
            }

            Section("Translator") {
                Button {
                    showPresets = true
                } label: {
                    HStack {
                        Label("Language Presets", systemImage: "globe").foregroundStyle(.primary)
                        Spacer()
                        Text("\(translationViewModel.languagePresets.count)").foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    TranslationHistoryView(translations: translationViewModel.recentTranslations)
                } label: {
                    Label("Translation History", systemImage: "clock.arrow.circlepath")
                }
                NavigationLink {
                    TranslationFavoritesView(favorites: translationViewModel.favoriteTranslations)
                } label: {
                    Label("Favorite Translations", systemImage: "heart.fill")
                }
            }

            Section {
                AITranslationConsentToggle()
            } footer: {
                Text("Standard translation is fast for everyday conversation. Advanced takes a moment longer and handles slang and context better.")
            }
        }
        .navigationTitle("Language & Translation")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPresets) {
            LanguagePresetsView(viewModel: translationViewModel, isPresented: $showPresets)
        }
    }
}

// MARK: - Audio & Video

struct AudioVideoSettingsPage: View {
    @ObservedObject private var settingsManager = SettingsManager.shared

    var body: some View {
        List {
            Section("Audio") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Volume", systemImage: "speaker.wave.2.fill")
                        Spacer()
                        Text("\(Int(settingsManager.settings.audio.volume * 100))%").foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { settingsManager.settings.audio.volume },
                        set: { settingsManager.setVolume($0) }
                    ), in: 0...1)
                }
                .padding(.vertical, 4)

                Toggle(isOn: Binding(
                    get: { settingsManager.settings.audio.speakerMode },
                    set: { value in
                        var audio = settingsManager.settings.audio
                        audio.speakerMode = value
                        settingsManager.updateAudioSettings(audio)
                    }
                )) {
                    Label("Start Calls on Speaker", systemImage: "speaker.fill")
                }

                Toggle(isOn: Binding(
                    get: { settingsManager.settings.audio.vibration },
                    set: { value in
                        var audio = settingsManager.settings.audio
                        audio.vibration = value
                        settingsManager.updateAudioSettings(audio)
                    }
                )) {
                    Label("Vibration", systemImage: "iphone.radiowaves.left.and.right")
                }

                HStack {
                    Label("Ringtone", systemImage: "bell.fill")
                    Spacer()
                    Text("iPhone Ringtone").foregroundStyle(.secondary)
                }
            }

            Section("Video") {
                Picker(selection: Binding(
                    get: { settingsManager.settings.video.quality },
                    set: { settingsManager.setVideoQuality($0) }
                )) {
                    ForEach(VideoQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                } label: {
                    Label("Video Quality", systemImage: "video.fill")
                }
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.video.mirrorFrontCamera },
                    set: { settingsManager.setMirrorFrontCamera($0) }
                )) {
                    Label("Mirror Front Camera", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                }
            }

            Section {
                SettingsSheetRow {
                    VoiceSettingsView()
                } label: {
                    Label("Translated Voice", systemImage: "waveform")
                }
            } footer: {
                Text("The voice people hear when your speech is translated on a call.")
            }
        }
        .navigationTitle("Audio & Video")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Notifications

struct NotificationsSettingsPage: View {
    @ObservedObject private var settingsManager = SettingsManager.shared

    var body: some View {
        List {
            Section {
                PushNotificationsToggle()
            } footer: {
                Text("Lets messages and calls reach you when Let Talk is closed.")
            }

            Section("Show Notifications For") {
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.notifications.messages },
                    set: { settingsManager.setMessageNotifications($0) }
                )) {
                    Label("Messages", systemImage: "message.fill")
                }
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.notifications.calls },
                    set: { settingsManager.setCallNotifications($0) }
                )) {
                    Label("Calls", systemImage: "phone.fill")
                }
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Sounds & Banners in iPhone Settings", systemImage: "gearshape")
                }
            } footer: {
                Text("Message previews arrive already translated into your language.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy & Safety

struct PrivacySafetySettingsPage: View {
    @ObservedObject private var settingsManager = SettingsManager.shared

    var body: some View {
        List {
            Section("Visibility") {
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.privacy.showOnlineStatus },
                    set: { settingsManager.setShowOnlineStatus($0) }
                )) {
                    Label("Show Online Status", systemImage: "circle.fill")
                }
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.privacy.allowCalls },
                    set: { value in
                        var privacy = settingsManager.settings.privacy
                        privacy.allowCalls = value
                        settingsManager.updatePrivacySettings(privacy)
                    }
                )) {
                    Label("Allow Incoming Calls", systemImage: "phone.arrow.down.left")
                }
            }

            Section {
                SettingsSheetRow {
                    BlockedUsersView()
                } label: {
                    Label("Blocked Users", systemImage: "hand.raised.fill")
                }
            } footer: {
                Text("Blocked people can't call you or message you. To report someone, open their chat or contact card and tap Report.")
            }
        }
        .navigationTitle("Privacy & Safety")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Data & Storage

struct DataStorageSettingsPage: View {
    @ObservedObject var translationViewModel: UnifiedTranslationViewModel
    @State private var showDataManagement = false
    @State private var showExport = false
    @State private var showImport = false

    var body: some View {
        List {
            Section {
                Button { showDataManagement = true } label: {
                    Label("Manage Stored Data", systemImage: "externaldrive.fill")
                }
                Button { showExport = true } label: {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }
                Button { showImport = true } label: {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                }
            }
        }
        .navigationTitle("Data & Storage")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDataManagement) { DataManagementView(translationViewModel: translationViewModel) }
        .sheet(isPresented: $showExport) { ExportSettingsView(translationViewModel: translationViewModel) }
        .sheet(isPresented: $showImport) { ImportSettingsView(translationViewModel: translationViewModel) }
    }
}

// MARK: - Help & Legal

struct HelpLegalSettingsPage: View {
    var body: some View {
        List {
            Section {
                Link(destination: LegalURLs.support) {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }
                Link(destination: LegalURLs.privacy) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                Link(destination: LegalURLs.terms) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
            }
            AboutSection()
        }
        .navigationTitle("Help & Legal")
        .navigationBarTitleDisplayMode(.inline)
    }
}
