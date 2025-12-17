//
//  let_talk_3_0App.swift
//  let talk 3.0
//
//  Created by Demetrius H on 9/7/25.
//

import SwiftUI
import UserNotifications
// import GoogleSignIn // Uncomment when GoogleSignIn SDK is added to project

@main
struct let_talk_3_0App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
        @StateObject private var authManager = AuthManager.shared
        @StateObject private var notificationManager = NotificationManager.shared
        @StateObject private var dataPersistence = DataPersistenceManager.shared
        @StateObject private var settingsManager = SettingsManager.shared
        @State private var isSplashActive = true
        @State private var splashTimer: Timer?
        
        // Computed property for preferred color scheme based on settings
        private var preferredColorScheme: ColorScheme? {
            switch settingsManager.settings.theme {
            case .light:
                return .light
            case .dark:
                return .dark
            case .system:
                return nil // Use system default
            case .ocean, .sunset, .forest, .lavender, .fire, .arctic, .cosmic:
                return nil // Use system default for gradient themes
            }
        }
        
        var body: some Scene {
            WindowGroup {
                ZStack {
                    // Gradient background for gradient themes
                    if settingsManager.settings.theme.isGradient {
                        LinearGradient(
                            gradient: Gradient(colors: settingsManager.settings.theme.gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        .opacity(0.1) // Subtle background
                    }
                    
                    if isSplashActive {
                        SplashScreenView()
                            .environmentObject(authManager)
                            .environmentObject(settingsManager)
                    } else {
                        if authManager.isAuthenticated {
                            MainTabView()
                                .environmentObject(authManager)
                                .environmentObject(notificationManager)
                                .environmentObject(dataPersistence)
                                .environmentObject(settingsManager)
                        } else {
                            // Check if user has completed onboarding
                            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                            
                            if !hasCompletedOnboarding {
                                OnboardingView()
                            } else {
                                EnhancedAuthView()
                                    .environmentObject(authManager)
                                    .environmentObject(settingsManager)
                            }
                        }
                    }
                    
                    // Inbound Call Overlay
                    IncomingCallOverlay()
                    
                    // Dynamic Island Views
                    DynamicIslandViews()
                }
                .preferredColorScheme(preferredColorScheme)
                .onAppear {
                    startSplashTimer()
                }
                .onChange(of: authManager.isAuthenticated) { isAuthenticated in
                    // Force UI update when authentication state changes
                    // This ensures the navigation happens immediately
                    print("Authentication state changed: \(isAuthenticated)")
                    
                    // Ensure splash screen is dismissed when auth state changes
                    if isSplashActive {
                        dismissSplashScreen()
                    }
                }
            }
        }
        
        // MARK: - Splash Screen Management
        private func startSplashTimer() {
            // Dismiss splash screen after 3 seconds regardless of auth state
            splashTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                dismissSplashScreen()
            }
        }
        
        private func dismissSplashScreen() {
            splashTimer?.invalidate()
            splashTimer = nil
            
            withAnimation(.easeInOut(duration: 0.5)) {
                isSplashActive = false
            }
        }
        
        // MARK: - Debug Helper (for testing splash screen)
        private func resetSplashScreen() {
            // Reset onboarding state to see splash screen again
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            isSplashActive = true
            startSplashTimer()
        }
    }

    class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication,
                        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
            // Configure Google Sign-In (uncomment when SDK is added)
            /*
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               let plist = NSDictionary(contentsOfFile: path),
               let clientId = plist["CLIENT_ID"] as? String {
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
            }
            */
            
            // Configure Push Notifications
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.delegate = NotificationManager.shared
            
            // Request notification permissions
            notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    Task { @MainActor in
                        application.registerForRemoteNotifications()
                    }
                }
            }
            
            return true
        }
        
        func application(_ application: UIApplication,
                        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            // Store APNs token (hex string). If you later implement server-side pushes,
            // you can upload this to Supabase (e.g. to `profiles.device_tokens`).
            let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
            UserDefaults.standard.set(token, forKey: "apnsToken")
            Task {
                await NotificationManager.shared.didRegisterForRemoteNotifications(token: token)
            }
        }
        
        func application(_ application: UIApplication,
                        didFailToRegisterForRemoteNotificationsWithError error: Error) {
            print("Failed to register for remote notifications: \(error)")
        }
    }

    // MARK: - Environment Keys
    struct UserDefaultsKey {
        static let theme = "app.theme"
        static let language = "app.language"
        static let notifications = "app.notifications"
        static let autoTranslate = "app.autoTranslate"
        static let lastSyncTime = "app.lastSyncTime"
    }

    // MARK: - Global Environment Objects
    class GlobalEnvironment: ObservableObject {
        static let shared = GlobalEnvironment()
        
        @Published var selectedTheme: Theme = .system
        @Published var selectedLanguage: Language = .english
        @Published var isNetworkAvailable = true
        
        private init() {
            // Load saved preferences
            if let savedTheme = UserDefaults.standard.string(forKey: UserDefaultsKey.theme),
               let theme = Theme(rawValue: savedTheme) {
                selectedTheme = theme
            }
            
            if let savedLanguage = UserDefaults.standard.string(forKey: UserDefaultsKey.language),
               let language = Language(rawValue: savedLanguage) {
                selectedLanguage = language
            }
            
            // Start monitoring network status
            startNetworkMonitoring()
        }
        
        private func startNetworkMonitoring() {
            // Implement network reachability monitoring
        }
    }

    enum Theme: String {
        case light
        case dark
        case system
    }

    enum Language: String {
        case english = "en"
        case spanish = "es"
        case french = "fr"
        case german = "de"
        case chinese = "zh"
        case japanese = "ja"
        case korean = "ko"
        // Add more languages as needed
    }


