//
//  Let_Talk_3_0App.swift
//  Let Talk 3.0
//
//  Created by Demetrius H on 12/18/25.
//

import SwiftUI
import UserNotifications
// import GoogleSignIn // Uncomment when GoogleSignIn SDK is added to project

@main
struct Let_Talk_3_0App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var dataPersistence = DataPersistenceManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var aiConsent = AIConsent.shared
    @State private var isSplashActive = true
    @State private var splashTimer: Timer?
    
    // Light / dark from Settings › Appearance (nil = follow the iPhone).
    private var preferredColorScheme: ColorScheme? {
        settingsManager.settings.theme.colorScheme
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
                    .opacity(0.18) // Subtle background
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
                                .environmentObject(authManager)
                                .environmentObject(settingsManager)
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
            .tint(settingsManager.settings.theme.accent)
            // The whole app in the language picked in Settings (instantly, no restart).
            .appLanguage(settingsManager.settings.language)
            .onChange(of: settingsManager.settings.theme) { _, theme in settingsManager.applyTheme(theme) }
            // Every scroll view in the app (lists, chats, settings) closes the keyboard when dragged.
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $aiConsent.needsPrompt) {
                AIConsentView()
            }
            .onAppear {
                startSplashTimer()
                CallKitManager.shared.registerVoIP()
                KeyboardDismisser.install()   // tap outside a text field closes the keyboard, app-wide
            }
            // OAuth return (lettalk://auth-callback). The in-app Google sheet normally catches it
            // itself; this covers the case where the system hands the link to the app instead.
            .onOpenURL { url in
                SupabaseManager.client.auth.handle(url)
            }
            .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
                // Force UI update when authentication state changes
                // This ensures the navigation happens immediately
                if newValue {
                    CallKitManager.shared.uploadPendingToken()
                    NotificationManager.shared.uploadPendingToken()
                    Task { await AuthManager.shared.syncLanguage(SettingsManager.shared.settings.language) }
                    Task { await ModerationManager.shared.refresh() }
                }

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
        // VoIP pushes must be registered at launch, not when a screen appears: when the app is
        // closed, iOS wakes it in the background for an incoming call and no screen ever appears,
        // so the call was never delivered (and iOS stops sending VoIP pushes to apps that miss them).
        CallKitManager.shared.registerVoIP()
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
        debugLog("Failed to register for remote notifications: \(error)")
    }
}
