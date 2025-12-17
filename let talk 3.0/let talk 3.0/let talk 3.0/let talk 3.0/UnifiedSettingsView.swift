import SwiftUI

struct UnifiedSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var translationViewModel: UnifiedTranslationViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showResetPasswordAlert = false
    @State private var showThemeSettings = false
    @State private var showLanguageSettings = false
    @State private var showNotificationSettings = false
    @State private var showPrivacySettings = false
    @State private var showAudioSettings = false
    @State private var showDataManagement = false
    @State private var showProfileEditor = false
    @State private var showExportSettings = false
    @State private var showImportSettings = false
    @State private var isResettingPassword = false
    @State private var isDeletingAccount = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                profileSection
                
                // Translation Settings Section
                translationSection
                
                // Appearance Section
                appearanceSection
                
                // Language & Translation Section
                languageSection
                
                // Audio & Video Section
                audioVideoSection
                
                // Notifications Section
                notificationsSection
                
                // Privacy Section
                privacySection
                
                // Data Management Section
                dataManagementSection
                
                // Account Section
                accountSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    try await authManager.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .alert("Reset Password", isPresented: $showResetPasswordAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Send Reset Email") {
                resetPassword()
            }
        } message: {
            Text("We'll send a password reset link to your email address.")
        }
        .sheet(isPresented: $showThemeSettings) {
            ThemeSettingsView()
        }
        .sheet(isPresented: $showLanguageSettings) {
            LanguageSettingsView()
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsView()
        }
        .sheet(isPresented: $showPrivacySettings) {
            PrivacySettingsView()
        }
        .sheet(isPresented: $showAudioSettings) {
            AudioSettingsView()
        }
        .sheet(isPresented: $showDataManagement) {
            DataManagementView(translationViewModel: translationViewModel)
        }
        .sheet(isPresented: $showProfileEditor) {
            ProfileEditorView()
        }
        .sheet(isPresented: $showExportSettings) {
            ExportSettingsView(translationViewModel: translationViewModel)
        }
        .sheet(isPresented: $showImportSettings) {
            ImportSettingsView(translationViewModel: translationViewModel)
        }
    }
    
    // MARK: - Profile Section
    private var profileSection: some View {
        Section {
            Button(action: { showProfileEditor = true }) {
                HStack {
                    ProfileImageView(
                        imageURL: authManager.currentUser?.photoURL,
                        placeholderText: String(authManager.currentUser?.name.prefix(1) ?? "U"),
                        size: 60
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authManager.currentUser?.name ?? "User")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(authManager.currentUser?.email ?? "No email")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Tap to edit profile")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        } header: {
            Text("Profile")
        }
    }
    
    // MARK: - Translation Section
    private var translationSection: some View {
        Section {
            NavigationLink(destination: LanguagePresetsView(
                viewModel: translationViewModel,
                isPresented: .constant(false)
            )) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Language Presets")
                    Spacer()
                    Text("\(translationViewModel.languagePresets.count)")
                        .foregroundColor(.secondary)
                }
            }
            
            NavigationLink(destination: TranslationHistoryView(
                translations: translationViewModel.recentTranslations
            )) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    Text("Translation History")
                    Spacer()
                    Text("\(translationViewModel.recentTranslations.count)")
                        .foregroundColor(.secondary)
                }
            }
            
            NavigationLink(destination: TranslationFavoritesView(
                favorites: translationViewModel.favoriteTranslations
            )) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("Favorite Translations")
                    Spacer()
                    Text("\(translationViewModel.favoriteTranslations.count)")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Translation")
        }
    }
    
    // MARK: - Appearance Section
    private var appearanceSection: some View {
        Section {
            Button(action: { showThemeSettings = true }) {
                HStack {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    Text("Theme")
                    Spacer()
                    Text(settingsManager.settings.theme.displayName)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        } header: {
            Text("Appearance")
        }
    }
    
    // MARK: - Language Section
    private var languageSection: some View {
        Section {
            Button(action: { showLanguageSettings = true }) {
                HStack {
                    Image(systemName: "globe.americas.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("App Language")
                    Spacer()
                    Text(settingsManager.settings.language.uppercased())
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack {
                Image(systemName: "textformat.abc")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                Text("Default Source Language")
                Spacer()
                Text(settingsManager.settings.sourceLanguage.uppercased())
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "textformat.abc.dottedunderline")
                    .foregroundColor(.green)
                    .frame(width: 24)
                Text("Default Target Language")
                Spacer()
                Text(settingsManager.settings.targetLanguage.uppercased())
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Language & Translation")
        }
    }
    
    // MARK: - Audio & Video Section
    private var audioVideoSection: some View {
        Section {
            Button(action: { showAudioSettings = true }) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Audio Settings")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack {
                Image(systemName: "volume.2")
                    .foregroundColor(.green)
                    .frame(width: 24)
                Text("Volume")
                Spacer()
                Text("\(Int(settingsManager.settings.audio.volume * 100))%")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                Text("Ringtone")
                Spacer()
                Text(settingsManager.settings.audio.ringtone.capitalized)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Audio & Video")
        }
    }
    
    // MARK: - Notifications Section
    private var notificationsSection: some View {
        Section {
            Button(action: { showNotificationSettings = true }) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("Notification Settings")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Toggle(isOn: Binding(
                get: { settingsManager.settings.notifications.messages },
                set: { settingsManager.settings.notifications.messages = $0 }
            )) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Message Notifications")
                }
            }
            
            Toggle(isOn: Binding(
                get: { settingsManager.settings.notifications.calls },
                set: { settingsManager.settings.notifications.calls = $0 }
            )) {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    Text("Call Notifications")
                }
            }
            
            Toggle(isOn: Binding(
                get: { settingsManager.settings.notifications.translations },
                set: { settingsManager.settings.notifications.translations = $0 }
            )) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    Text("Translation Notifications")
                }
            }
        } header: {
            Text("Notifications")
        }
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        Section {
            Button(action: { showPrivacySettings = true }) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("Privacy Settings")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Toggle(isOn: Binding(
                get: { settingsManager.settings.privacy.showOnlineStatus },
                set: { settingsManager.settings.privacy.showOnlineStatus = $0 }
            )) {
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    Text("Show Online Status")
                }
            }
            
            Toggle(isOn: Binding(
                get: { settingsManager.settings.privacy.allowCalls },
                set: { settingsManager.settings.privacy.allowCalls = $0 }
            )) {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Allow Incoming Calls")
                }
            }
            
            Toggle(isOn: Binding(
                get: { settingsManager.settings.privacy.allowMessages },
                set: { settingsManager.settings.privacy.allowMessages = $0 }
            )) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text("Allow Incoming Messages")
                }
            }
        } header: {
            Text("Privacy")
        }
    }
    
    // MARK: - Data Management Section
    private var dataManagementSection: some View {
        Section {
            Button(action: { showDataManagement = true }) {
                HStack {
                    Image(systemName: "externaldrive.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Data Management")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { showExportSettings = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    Text("Export Data")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { showImportSettings = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text("Import Data")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        } header: {
            Text("Data Management")
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        Section {
            Button(action: { showResetPasswordAlert = true }) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Reset Password")
                    Spacer()
                    if isResettingPassword {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isResettingPassword)
            
            Button(action: { showSignOutAlert = true }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text("Sign Out")
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { showDeleteAccountAlert = true }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("Delete Account")
                }
            }
            .buttonStyle(PlainButtonStyle())
        } header: {
            Text("Account")
        }
    }
    
    // MARK: - Helper Methods
    private func resetPassword() {
        guard let email = authManager.currentUser?.email else { return }
        
        isResettingPassword = true
        
        Task {
            do {
                try await authManager.resetPassword(email: email)
                DispatchQueue.main.async {
                    self.isResettingPassword = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isResettingPassword = false
                    // Handle error
                }
            }
        }
    }
    
    private func deleteAccount() {
        isDeletingAccount = true
        
        Task {
            do {
                try await authManager.deleteAccount()
                DispatchQueue.main.async {
                    self.isDeletingAccount = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDeletingAccount = false
                    // Handle error
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct TranslationHistoryView: View {
    let translations: [UnifiedTranslationHistory]
    
    var body: some View {
        List(translations) { translation in
            VStack(alignment: .leading, spacing: 8) {
                Text(translation.sourceText)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(translation.translatedText)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(translation.sourceLanguage.code.uppercased()) → \(translation.targetLanguage.code.uppercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(translation.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Translation History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TranslationFavoritesView: View {
    let favorites: [UnifiedTranslationHistory]
    
    var body: some View {
        List(favorites) { translation in
            VStack(alignment: .leading, spacing: 8) {
                Text(translation.sourceText)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(translation.translatedText)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(translation.sourceLanguage.code.uppercased()) → \(translation.targetLanguage.code.uppercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(translation.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Favorite Translations")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Settings Views

struct LanguageSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    
    private let languages = [
        ("en", "English"),
        ("es", "Español"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("it", "Italiano"),
        ("pt", "Português"),
        ("ru", "Русский"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("zh", "中文")
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("App Language") {
                    Text("Choose your preferred language for the app interface")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ForEach(languages, id: \.0) { code, name in
                            Button(action: {
                                settingsManager.setLanguage(code)
                            }) {
                                HStack {
                                    Text(name)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if settingsManager.settings.language == code {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.bold)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Section("Translation Languages") {
                    Text("Default languages for translation")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Source Language")
                            Spacer()
                            Text(settingsManager.settings.sourceLanguage)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Target Language")
                            Spacer()
                            Text(settingsManager.settings.targetLanguage)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Language Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct PrivacySettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Visibility") {
                    Toggle("Show Online Status", isOn: Binding(
                        get: { settingsManager.settings.privacy.showOnlineStatus },
                        set: { value in
                            var privacy = settingsManager.settings.privacy
                            privacy.showOnlineStatus = value
                            settingsManager.updatePrivacySettings(privacy)
                        }
                    ))
                    
                    Toggle("Allow Incoming Calls", isOn: Binding(
                        get: { settingsManager.settings.privacy.allowCalls },
                        set: { value in
                            var privacy = settingsManager.settings.privacy
                            privacy.allowCalls = value
                            settingsManager.updatePrivacySettings(privacy)
                        }
                    ))
                    
                    Toggle("Allow Messages", isOn: Binding(
                        get: { settingsManager.settings.privacy.allowMessages },
                        set: { value in
                            var privacy = settingsManager.settings.privacy
                            privacy.allowMessages = value
                            settingsManager.updatePrivacySettings(privacy)
                        }
                    ))
                    
                    Toggle("Share Location", isOn: Binding(
                        get: { settingsManager.settings.privacy.shareLocation },
                        set: { value in
                            var privacy = settingsManager.settings.privacy
                            privacy.shareLocation = value
                            settingsManager.updatePrivacySettings(privacy)
                        }
                    ))
                }
                
                Section("Data & Privacy") {
                    Text("Your privacy is important to us. These settings control how your information is shared and used within the app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct NotificationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Notifications") {
                    Toggle("Message Notifications", isOn: Binding(
                        get: { settingsManager.settings.notifications.messages },
                        set: { value in
                            var notifications = settingsManager.settings.notifications
                            notifications.messages = value
                            settingsManager.updateNotificationSettings(notifications)
                        }
                    ))
                    
                    Toggle("Call Notifications", isOn: Binding(
                        get: { settingsManager.settings.notifications.calls },
                        set: { value in
                            var notifications = settingsManager.settings.notifications
                            notifications.calls = value
                            settingsManager.updateNotificationSettings(notifications)
                        }
                    ))
                    
                    Toggle("Translation Notifications", isOn: Binding(
                        get: { settingsManager.settings.notifications.translations },
                        set: { value in
                            var notifications = settingsManager.settings.notifications
                            notifications.translations = value
                            settingsManager.updateNotificationSettings(notifications)
                        }
                    ))
                    
                    Toggle("Push Notifications", isOn: Binding(
                        get: { settingsManager.settings.notifications.push },
                        set: { value in
                            var notifications = settingsManager.settings.notifications
                            notifications.push = value
                            settingsManager.updateNotificationSettings(notifications)
                        }
                    ))
                }
                
                Section("Notification Preferences") {
                    Text("Customize which notifications you receive to stay informed about your conversations and calls.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct AudioSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Audio Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Volume")
                            .font(.headline)
                        
                        Slider(value: Binding(
                            get: { settingsManager.settings.audio.volume },
                            set: { settingsManager.setVolume($0) }
                        ), in: 0...1)
                        .accentColor(.blue)
                        
                        Text("\(Int(settingsManager.settings.audio.volume * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Toggle("Vibration", isOn: Binding(
                        get: { settingsManager.settings.audio.vibration },
                        set: { value in
                            var audio = settingsManager.settings.audio
                            audio.vibration = value
                            settingsManager.updateAudioSettings(audio)
                        }
                    ))
                    
                    Toggle("Speaker Mode", isOn: Binding(
                        get: { settingsManager.settings.audio.speakerMode },
                        set: { value in
                            var audio = settingsManager.settings.audio
                            audio.speakerMode = value
                            settingsManager.updateAudioSettings(audio)
                        }
                    ))
                }
                
                Section("Ringtone") {
                    HStack {
                        Text("Ringtone")
                        Spacer()
                        Text(settingsManager.settings.audio.ringtone)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct DataManagementView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var translationViewModel: UnifiedTranslationViewModel
    @State private var showClearDataAlert = false
    @State private var isClearingData = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Translation Data") {
                    Button(action: { showClearDataAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Translation History")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isClearingData)
                }
                
                Section("Storage Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Translation History")
                            .font(.headline)
                        
                        let count = translationViewModel.recentTranslations.count
                        Text("\(count) translations saved")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Data Management") {
                    Text("Manage your translation data and clear history when needed. This helps keep your app running smoothly.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Data Management")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .alert("Clear Translation History", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearTranslationData()
                }
            } message: {
                Text("This will permanently delete all your translation history. This action cannot be undone.")
            }
        }
    }
    
    private func clearTranslationData() {
        isClearingData = true
        translationViewModel.recentTranslations.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isClearingData = false
        }
    }
}

struct ExportSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var translationViewModel: UnifiedTranslationViewModel
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportData: Data?
    
    var body: some View {
        NavigationView {
            List {
                Section("Export Options") {
                    Button(action: exportTranslations) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("Export Translation History")
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isExporting)
                }
                
                Section("Export Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Translation History")
                            .font(.headline)
                        
                        Text("Export your translation history as a JSON file for backup or analysis.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Export Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .sheet(isPresented: $showShareSheet) {
                if let data = exportData {
                    SettingsShareSheet(activityItems: [data])
                }
            }
        }
    }
    
    private func exportTranslations() {
        isExporting = true
        
        // Create export data
        let exportObject = [
            "translations": translationViewModel.recentTranslations.map { translation in
                [
                    "id": translation.id,
                    "sourceText": translation.sourceText,
                    "translatedText": translation.translatedText,
                    "sourceLanguage": translation.sourceLanguage.code,
                    "targetLanguage": translation.targetLanguage.code,
                    "timestamp": ISO8601DateFormatter().string(from: translation.timestamp)
                ]
            }
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportObject, options: .prettyPrinted)
            exportData = jsonData
            showShareSheet = true
        } catch {
            print("Export failed: \(error)")
        }
        
        isExporting = false
    }
}

struct ImportSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var translationViewModel: UnifiedTranslationViewModel
    @State private var isImporting = false
    @State private var showDocumentPicker = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Import Options") {
                    Button(action: { showDocumentPicker = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.blue)
                            Text("Import Translation History")
                            Spacer()
                            if isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isImporting)
                }
                
                Section("Import Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Translation History")
                            .font(.headline)
                        
                        Text("Import translation history from a previously exported JSON file.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Import Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .sheet(isPresented: $showDocumentPicker) {
                SettingsDocumentPicker { url in
                    importTranslations(from: url)
                }
            }
        }
    }
    
    private func importTranslations(from url: URL) {
        isImporting = true
        
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            
            if let dict = json as? [String: Any],
               let translations = dict["translations"] as? [[String: Any]] {
                
                for translationData in translations {
                    // Create translation object from imported data
                    // This would need to be implemented based on your translation model
                    print("Importing translation: \(translationData)")
                }
            }
        } catch {
            print("Import failed: \(error)")
        }
        
        isImporting = false
    }
}

// MARK: - Helper Views

struct SettingsShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingsDocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: SettingsDocumentPicker
        
        init(_ parent: SettingsDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
        }
    }
}
