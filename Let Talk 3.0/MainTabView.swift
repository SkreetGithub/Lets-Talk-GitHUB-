import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var settingsManager: SettingsManager
    @StateObject private var tabViewModel = MainTabViewModel()
    @State private var selectedTab = Tab.contacts
    @State private var showNewChat = false
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var isTabBarVisible = true
    @State private var lastSelectedTab: Tab = .contacts
    
    enum Tab: CaseIterable {
        case chats
        case calls
        case contacts
        case translator
        
        var title: String {
            switch self {
            case .chats: return "Chats"
            case .calls: return "Calls"
            case .contacts: return "Contacts"
            case .translator: return "Translator"
            }
        }
        
        var icon: String {
            switch self {
            case .chats: return "message.fill"
            case .calls: return "phone.fill"
            case .contacts: return "person.2.fill"
            case .translator: return "text.bubble.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .chats: return .blue
            case .calls: return .green
            case .contacts: return .orange
            case .translator: return .purple
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Main Content
                TabView(selection: $selectedTab) {
                    // Chats Tab
                    ComprehensiveChatsView(showNewChat: $showNewChat)
                        .tag(Tab.chats)
                        .environmentObject(settingsManager)
                        .environmentObject(authManager)
                    
                    // Calls Tab
                    CallsView()
                        .tag(Tab.calls)
                        .environmentObject(settingsManager)
                        .environmentObject(authManager)
                    
                    // Contacts Tab
                    ContactsView()
                        .tag(Tab.contacts)
                        .environmentObject(settingsManager)
                        .environmentObject(authManager)
                    
                    // Translator Tab
                    ProfessionalTranslatorView()
                        .tag(Tab.translator)
                        .environmentObject(settingsManager)
                        .environmentObject(authManager)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
                .gesture(swipeGesture)
                .onChange(of: selectedTab) { oldValue, newTab in
                    handleTabChange(newTab)
                }
                
                // Custom Tab Bar
                if isTabBarVisible {
                    CustomTabBar(
                        selectedTab: $selectedTab,
                        showSettings: $showSettings,
                        showProfile: $showProfile,
                        showNotifications: $showNotifications
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text(selectedTab.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // Tab-specific actions
                        HStack(spacing: 16) {
                            tabSpecificActions
                        }
                    }
                }
            }
        }
        .accentColor(.blue)
        .onAppear {
            tabViewModel.setupUserPresence()
            setupInitialState()
        }
        .onDisappear {
            tabViewModel.cleanupUserPresence()
        }
        .sheet(isPresented: $showNewChat) {
            NewChatView()
                .environmentObject(authManager)
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showSettings) {
            UnifiedSettingsView(translationViewModel: UnifiedTranslationViewModel())
                .environmentObject(settingsManager)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showProfile) {
            ProfileEditorView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationSettingsView()
                .environmentObject(settingsManager)
        }
    }
    
    // MARK: - Tab-Specific Actions
    @ViewBuilder
    private var tabSpecificActions: some View {
        switch selectedTab {
        case .chats:
            Button(action: { showNewChat = true }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .medium))
            }
            
        case .calls:
            Button(action: { 
                // Show dialpad for calls
                // This will be handled by the CallsView
            }) {
                Image(systemName: "phone.circle.fill")
                    .font(.system(size: 16, weight: .medium))
            }
            
        case .contacts:
            Button(action: { 
                // Show add contact
                // This will be handled by the ContactsView
            }) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 16, weight: .medium))
            }
            
        case .translator:
            Button(action: { 
                // Show language selector
                // This will be handled by the ProfessionalTranslatorView
            }) {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .medium))
            }
        }
    }
    
    // MARK: - Helper Methods
    private func setupInitialState() {
        // Set up initial state based on user preferences
        if let lastTab = UserDefaults.standard.string(forKey: "lastSelectedTab"),
           let tab = Tab.allCases.first(where: { $0.title == lastTab }) {
            selectedTab = tab
        }
    }
    
    private func handleTabChange(_ newTab: Tab) {
        // Save the last selected tab
        UserDefaults.standard.set(newTab.title, forKey: "lastSelectedTab")
        lastSelectedTab = newTab
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Handle tab-specific logic
        switch newTab {
        case .chats:
            // Refresh chats if needed
            break
        case .calls:
            // Refresh calls if needed
            break
        case .contacts:
            // Refresh contacts if needed
            break
        case .translator:
            // Initialize translator if needed
            break
        }
    }
    
    // MARK: - Tab Navigation Functions
    private func switchToNextTab() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch selectedTab {
            case .chats:
                selectedTab = .calls
            case .calls:
                selectedTab = .contacts
            case .contacts:
                selectedTab = .translator
            case .translator:
                selectedTab = .chats // Loop back to first tab
            }
        }
    }
    
    private func switchToPreviousTab() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch selectedTab {
            case .chats:
                selectedTab = .translator // Loop back to last tab
            case .calls:
                selectedTab = .chats
            case .contacts:
                selectedTab = .calls
            case .translator:
                selectedTab = .contacts
            }
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                let threshold: CGFloat = 50
                if value.translation.width > threshold {
                    // Swipe right - go to previous tab
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    switchToPreviousTab()
                } else if value.translation.width < -threshold {
                    // Swipe left - go to next tab
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    switchToNextTab()
                }
            }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Binding var showSettings: Bool
    @Binding var showProfile: Bool
    @Binding var showNotifications: Bool
    @Namespace private var namespace
    @State private var showQuickActions = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Page Indicators
            HStack(spacing: 6) {
                ForEach(MainTabView.Tab.allCases, id: \.title) { tab in
                    Circle()
                        .fill(selectedTab == tab ? tab.color : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .scaleEffect(selectedTab == tab ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
            }
            .padding(.top, 8)
            
            // Tab Buttons
            HStack(spacing: 0) {
                ForEach(MainTabView.Tab.allCases, id: \.title) { tab in
                    TabButton(tab: tab,
                             selectedTab: $selectedTab,
                             namespace: namespace)
                }
                
                // Quick Actions Button
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showQuickActions.toggle()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: showQuickActions ? "xmark" : "ellipsis")
                            .font(.system(size: 18, weight: .medium))
                            .rotationEffect(.degrees(showQuickActions ? 45 : 0))
                            .animation(.easeInOut(duration: 0.2), value: showQuickActions)
                        
                        Text("More")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Quick Actions Menu
            if showQuickActions {
                QuickActionsMenu(
                    showSettings: $showSettings,
                    showProfile: $showProfile,
                    showNotifications: $showNotifications,
                    showQuickActions: $showQuickActions
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

struct TabButton: View {
    let tab: MainTabView.Tab
    @Binding var selectedTab: MainTabView.Tab
    var namespace: Namespace.ID
    
    var body: some View {
        Button(action: { 
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { 
                selectedTab = tab 
            } 
        }) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .medium))
                
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(selectedTab == tab ? .white : .gray)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                ZStack {
                    if selectedTab == tab {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [tab.color, tab.color.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .matchedGeometryEffect(id: "tab", in: namespace)
                            .shadow(color: tab.color.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickActionsMenu: View {
    @Binding var showSettings: Bool
    @Binding var showProfile: Bool
    @Binding var showNotifications: Bool
    @Binding var showQuickActions: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            // Settings Button
            QuickActionButton(
                icon: "gearshape.fill",
                title: "Settings",
                color: .blue
            ) {
                showSettings = true
                showQuickActions = false
            }
            
            // Profile Button
            QuickActionButton(
                icon: "person.circle.fill",
                title: "Profile",
                color: .green
            ) {
                showProfile = true
                showQuickActions = false
            }
            
            // Notifications Button
            QuickActionButton(
                icon: "bell.fill",
                title: "Notifications",
                color: .orange
            ) {
                showNotifications = true
                showQuickActions = false
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

class MainTabViewModel: ObservableObject {
    private var presenceTimer: Timer?
    
    func setupUserPresence() {
        // Update user's online status
        AuthManager.shared.updateOnlineStatus(isOnline: true)
        
        // Set up periodic presence updates
        presenceTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.updatePresence()
        }
        
        // Start listening for incoming calls (Supabase-backed signaling)
        FirebaseSignalingService.shared.startListeningForIncomingCalls()
    }
    
    func cleanupUserPresence() {
        presenceTimer?.invalidate()
        presenceTimer = nil
        AuthManager.shared.updateOnlineStatus(isOnline: false)
    }
    
    private func updatePresence() {
        AuthManager.shared.updateOnlineStatus(isOnline: true)
    }
    
    deinit {
        cleanupUserPresence()
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showProfileEditor = false
    @State private var showPhoneGenerator = false
    @State private var showLanguageSettings = false
    @State private var showThemeSettings = false
    
    private var phoneGeneratorButton: some View {
        Button(action: { showPhoneGenerator = true }) {
            HStack {
                Image(systemName: "phone.circle.fill")
                    .foregroundColor(.green)
                Text("Phone Number Generator")
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var languageSettingsButton: some View {
        Button(action: { showLanguageSettings = true }) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                Text("Language Preferences")
                Spacer()
                Text(settingsManager.settings.language)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section("Profile") {
                    Button(action: { showProfileEditor = true }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("Profile")
                                    .font(.headline)
                                Text("Edit your profile information")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Communication Section
                Section("Communication") {
                    phoneGeneratorButton
                    languageSettingsButton
                }
                
                // Appearance Section
                Section("Appearance") {
                    Button(action: { showThemeSettings = true }) {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.purple)
                            Text("Theme")
                            Spacer()
                            Text(settingsManager.settings.theme.rawValue.capitalized)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Notifications Section
                Section("Notifications") {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                        Text("Push Notifications")
                        Spacer()
                        Toggle("", isOn: $settingsManager.settings.notifications.push)
                    }
                    
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(.blue)
                        Text("Message Notifications")
                        Spacer()
                        Toggle("", isOn: $settingsManager.settings.notifications.messages)
                    }
                    
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.green)
                        Text("Call Notifications")
                        Spacer()
                        Toggle("", isOn: $settingsManager.settings.notifications.calls)
                    }
                }
                
                // Account Section
                Section {
                    Button("Sign Out") {
                        Task {
                            do {
                                // Brute force sign out - ensure it works
                                try await authManager.signOut()
                                
                                // Force dismiss the settings view immediately
                                await MainActor.run {
                                    presentationMode.wrappedValue.dismiss()
                                }
                                
                                // Additional safety: Force navigation after a short delay
                                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                                
                                // Ensure the main app navigation is triggered
                                await MainActor.run {
                                    // Force a UI update to ensure navigation happens
                                    if !authManager.isAuthenticated {
                                        print("User signed out - AuthView should be showing now")
                                        // Navigation should already be handled by the main app
                                        // but this ensures it happens
                                    }
                                }
                                
                            } catch {
                                // Even if there's an error, force dismiss and sign out
                                print("Sign out error: \(error)")
                                await MainActor.run {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .sheet(isPresented: $showProfileEditor) {
            ProfileEditorView()
        }
        .sheet(isPresented: $showPhoneGenerator) {
            PhoneGeneratorView()
        }
        .sheet(isPresented: $showLanguageSettings) {
            // Language settings will be handled in the main settings view
            EmptyView()
        }
        .sheet(isPresented: $showThemeSettings) {
            ThemeSettingsView()
        }
        .onChange(of: authManager.isAuthenticated) { oldValue, isAuthenticated in
            if !isAuthenticated {
                // Automatically dismiss settings when user is signed out
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

//NewChatView is defined in NewChatView.swift

class NewChatViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var isLoading = false
    
    private let databaseManager = DatabaseManager.shared
    
    func loadContacts() {
        isLoading = true
        Task {
            do {
                contacts = try await databaseManager.fetchContacts()
                isLoading = false
            } catch {
                isLoading = false
            }
        }
    }
    
    func startChat(with contact: Contact) {
        Task {
            do {
                try await databaseManager.createOrUpdateChat(
                    senderId: AuthManager.shared.currentUserId ?? "",
                    receiverId: contact.id
                )
            } catch {
                // Handle error
            }
        }
    }
}

// MARK: - Settings Sub-Views

struct TranslationToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: $isOn)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthManager.shared)
            .environmentObject(NotificationManager.shared)
    }
}

// MARK: - Missing Views

struct ProfileEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                        TextField("Full Name", text: $name)
                    }
                    
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.green)
                        TextField("Phone Number", text: $phone)
                            .keyboardType(.phonePad)
                    }
                    
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.orange)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .disabled(true)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    saveProfile()
                }
                .disabled(isLoading)
            )
        }
        .onAppear {
            loadProfile()
        }
        .alert("Profile", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadProfile() {
        guard let user = authManager.currentUser else { return }
        name = user.name
        phone = user.phone
        email = user.email
    }
    
    private func saveProfile() {
        isLoading = true
        
        Task {
            do {
                try await authManager.updateUserProfile(
                    name: name,
                    phone: phone,
                    profileImage: nil
                )
                
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Profile updated successfully!"
                    showAlert = true
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Failed to update profile: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

struct PhoneGeneratorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var generatedNumbers: [String] = []
    @State private var isGenerating = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Phone Number Generator")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Button(action: generateNumbers) {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text(isGenerating ? "Generating..." : "Generate Numbers")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .disabled(isGenerating)
                
                if !generatedNumbers.isEmpty {
                    List(generatedNumbers, id: \.self) { number in
                        HStack {
                            Text(number)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button("Copy") {
                                UIPasteboard.general.string = number
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Phone Generator")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
    
    private func generateNumbers() {
        isGenerating = true
        generatedNumbers.removeAll()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Generate 5 random phone numbers
            for _ in 0..<5 {
                let areaCode = String(format: "%03d", Int.random(in: 200...999))
                let exchange = String(format: "%03d", Int.random(in: 200...999))
                let number = String(format: "%04d", Int.random(in: 0...9999))
                generatedNumbers.append("+1 (\(areaCode)) \(exchange)-\(number)")
            }
            isGenerating = false
        }
    }
}

struct ThemeSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("App Theme") {
                    Text("Choose your preferred theme")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Button(action: {
                                settingsManager.setTheme(theme)
                            }) {
                                HStack {
                                    Image(systemName: theme.icon)
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    Text(theme.displayName)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if settingsManager.settings.theme == theme {
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
            }
            .navigationTitle("Theme Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}
