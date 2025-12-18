import SwiftUI

struct ComprehensiveSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var authManager: AuthManager
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showExportSettings = false
    @State private var showImportSettings = false
    @State private var showThemePreview = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                profileSection
                
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
                
                // Chat & Call Section
                chatCallSection
                
                // Data Management Section
                dataManagementSection
                
                // Account Section
                accountSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
                Task {
                    try await authManager.deleteAccount()
                }
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
    }
    
    // MARK: - Profile Section
    private var profileSection: some View {
        Section {
            HStack(spacing: 16) {
                // Profile Image
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(authManager.currentUser?.name.prefix(1).uppercased() ?? "U")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(authManager.currentUser?.name ?? "User")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(authManager.currentUser?.email ?? "user@example.com")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(authManager.currentUser?.phone ?? "No phone number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Edit") {
                    // Edit profile action
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Profile")
        }
    }
    
    // MARK: - Appearance Section
    private var appearanceSection: some View {
        Section {
            // Theme Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemePreviewCard(
                            theme: theme,
                            isSelected: settingsManager.settings.theme == theme,
                            action: {
                                settingsManager.setTheme(theme)
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 8)
            
            // Chat Bubble Colors
            VStack(alignment: .leading, spacing: 12) {
                Text("Chat Bubbles")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sent Messages")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                            ForEach(ChatBubbleColor.allCases, id: \.self) { color in
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: settingsManager.settings.chatBubbles.sentColor == color ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        settingsManager.setChatBubbleSentColor(color)
                                    }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Received Messages")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                            ForEach(ChatBubbleColor.allCases, id: \.self) { color in
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: settingsManager.settings.chatBubbles.receivedColor == color ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        settingsManager.setChatBubbleReceivedColor(color)
                                    }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            
            // Call Interface Background
            VStack(alignment: .leading, spacing: 12) {
                Text("Call Interface")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(CallBackgroundColor.allCases, id: \.self) { color in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color.color)
                                .frame(height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary, lineWidth: settingsManager.settings.callInterface.background == color ? 2 : 0)
                                )
                            
                            Text(color.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .onTapGesture {
                            settingsManager.setCallInterfaceBackground(color)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Appearance")
        }
    }
    
    // MARK: - Language Section
    private var languageSection: some View {
        Section {
            // App Language
            HStack {
                Text("App Language")
                Spacer()
                Text(settingsManager.settings.language.uppercased())
                    .foregroundColor(.secondary)
            }
            
            // Source Language
            HStack {
                Text("Default Source Language")
                Spacer()
                Text(settingsManager.settings.sourceLanguage.uppercased())
                    .foregroundColor(.secondary)
            }
            
            // Target Language
            HStack {
                Text("Default Target Language")
                Spacer()
                Text(settingsManager.settings.targetLanguage.uppercased())
                    .foregroundColor(.secondary)
            }
            
            // Translation Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Translation")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Toggle("Auto-translate", isOn: Binding(
                    get: { settingsManager.settings.translation.autoTranslate },
                    set: { settingsManager.setAutoTranslate($0) }
                ))
                
                Toggle("Voice Translation", isOn: Binding(
                    get: { settingsManager.settings.translation.voiceEnabled },
                    set: { settingsManager.setVoiceEnabled($0) }
                ))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Translation Provider")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Provider", selection: Binding(
                        get: { settingsManager.settings.translation.provider },
                        set: { settingsManager.setTranslationProvider($0) }
                    )) {
                        ForEach(TranslationProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confidence Level")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { settingsManager.settings.translation.confidence },
                            set: { settingsManager.setTranslationConfidence($0) }
                        ),
                        in: 0.1...1.0,
                        step: 0.1
                    )
                    
                    Text("\(Int(settingsManager.settings.translation.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Language & Translation")
        }
    }
    
    // MARK: - Audio & Video Section
    private var audioVideoSection: some View {
        Section {
            // Audio Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Audio")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Volume")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { settingsManager.settings.audio.volume },
                            set: { settingsManager.setVolume($0) }
                        ),
                        in: 0.0...1.0,
                        step: 0.1
                    )
                    
                    Text("\(Int(settingsManager.settings.audio.volume * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Toggle("Vibration", isOn: Binding(
                    get: { settingsManager.settings.audio.vibration },
                    set: { settingsManager.setVibration($0) }
                ))
                
                Toggle("Speaker Mode", isOn: Binding(
                    get: { settingsManager.settings.audio.speakerMode },
                    set: { settingsManager.setSpeakerMode($0) }
                ))
            }
            .padding(.vertical, 8)
            
            // Video Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Video")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quality")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Quality", selection: Binding(
                        get: { settingsManager.settings.video.quality },
                        set: { settingsManager.setVideoQuality($0) }
                    )) {
                        ForEach(VideoQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Toggle("Auto-start Video", isOn: Binding(
                    get: { settingsManager.settings.video.autoStart },
                    set: { settingsManager.setAutoStartVideo($0) }
                ))
                
                Toggle("Mirror Front Camera", isOn: Binding(
                    get: { settingsManager.settings.video.mirrorFrontCamera },
                    set: { settingsManager.setMirrorFrontCamera($0) }
                ))
            }
            .padding(.vertical, 8)
        } header: {
            Text("Audio & Video")
        }
    }
    
    // MARK: - Notifications Section
    private var notificationsSection: some View {
        Section {
            Toggle("Message Notifications", isOn: Binding(
                get: { settingsManager.settings.notifications.messages },
                set: { settingsManager.setMessageNotifications($0) }
            ))
            
            Toggle("Call Notifications", isOn: Binding(
                get: { settingsManager.settings.notifications.calls },
                set: { settingsManager.setCallNotifications($0) }
            ))
            
            Toggle("Translation Notifications", isOn: Binding(
                get: { settingsManager.settings.notifications.translations },
                set: { settingsManager.setTranslationNotifications($0) }
            ))
            
            Toggle("Push Notifications", isOn: Binding(
                get: { settingsManager.settings.notifications.push },
                set: { settingsManager.setPushNotifications($0) }
            ))
        } header: {
            Text("Notifications")
        }
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        Section {
            Toggle("Show Online Status", isOn: Binding(
                get: { settingsManager.settings.privacy.showOnlineStatus },
                set: { settingsManager.settings.privacy.showOnlineStatus = $0; settingsManager.saveSettings() }
            ))
            
            Toggle("Allow Calls", isOn: Binding(
                get: { settingsManager.settings.privacy.allowCalls },
                set: { settingsManager.settings.privacy.allowCalls = $0; settingsManager.saveSettings() }
            ))
            
            Toggle("Allow Messages", isOn: Binding(
                get: { settingsManager.settings.privacy.allowMessages },
                set: { settingsManager.settings.privacy.allowMessages = $0; settingsManager.saveSettings() }
            ))
            
            Toggle("Share Location", isOn: Binding(
                get: { settingsManager.settings.privacy.shareLocation },
                set: { settingsManager.settings.privacy.shareLocation = $0; settingsManager.saveSettings() }
            ))
        } header: {
            Text("Privacy")
        }
    }
    
    // MARK: - Chat & Call Section
    private var chatCallSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Chat Bubbles")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Corner Radius")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { settingsManager.settings.chatBubbles.cornerRadius },
                            set: { settingsManager.settings.chatBubbles.cornerRadius = $0; settingsManager.saveSettings() }
                        ),
                        in: 8.0...24.0,
                        step: 2.0
                    )
                    
                    Text("\(Int(settingsManager.settings.chatBubbles.cornerRadius))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font Size")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { settingsManager.settings.chatBubbles.fontSize },
                            set: { settingsManager.settings.chatBubbles.fontSize = $0; settingsManager.saveSettings() }
                        ),
                        in: 12.0...20.0,
                        step: 1.0
                    )
                    
                    Text("\(Int(settingsManager.settings.chatBubbles.fontSize))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Call Interface")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Toggle("Show Waveform", isOn: Binding(
                    get: { settingsManager.settings.callInterface.showWaveform },
                    set: { settingsManager.settings.callInterface.showWaveform = $0; settingsManager.saveSettings() }
                ))
            }
            .padding(.vertical, 8)
        } header: {
            Text("Chat & Call")
        }
    }
    
    // MARK: - Data Management Section
    private var dataManagementSection: some View {
        Section {
            Button("Export Settings") {
                showExportSettings = true
            }
            .foregroundColor(.blue)
            
            Button("Import Settings") {
                showImportSettings = true
            }
            .foregroundColor(.blue)
            
            Button("Reset to Defaults") {
                settingsManager.resetToDefaults()
            }
            .foregroundColor(.orange)
        } header: {
            Text("Data Management")
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        Section {
            Button("Sign Out") {
                showSignOutAlert = true
            }
            .foregroundColor(.red)
            
            Button("Delete Account") {
                showDeleteAccountAlert = true
            }
            .foregroundColor(.red)
        } header: {
            Text("Account")
        }
    }
}

// MARK: - Theme Preview Card
struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if theme.isGradient {
                    LinearGradient(
                        gradient: Gradient(colors: theme.gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme == .light ? Color.white : theme == .dark ? Color.black : Color.primary)
                        .frame(height: 40)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: theme.icon)
                        .font(.caption)
                    Text(theme.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.primary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ComprehensiveSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ComprehensiveSettingsView()
            .environmentObject(SettingsManager.shared)
            .environmentObject(AuthManager.shared)
    }
}
