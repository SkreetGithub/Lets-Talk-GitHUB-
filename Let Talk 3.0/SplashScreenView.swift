import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var showOnboarding = false
    @State private var showAuth = false
    @State private var showMainApp = false
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.6),
                    Color.pink.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // App Logo/Icon
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // App Name
                Text("Let Talk")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0).delay(0.5),
                        value: isAnimating
                    )
                
                // Tagline
                Text("Connect. Translate. Communicate.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0).delay(1.0),
                        value: isAnimating
                    )
                
                // Loading indicator
                if isAnimating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .animation(
                            Animation.easeInOut(duration: 1.0).delay(1.5),
                            value: isAnimating
                        )
                }
            }
        }
        .onAppear {
            startAnimation()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .fullScreenCover(isPresented: $showAuth) {
            AuthView()
        }
        .fullScreenCover(isPresented: $showMainApp) {
            MainTabView()
        }
    }
    
    private func startAnimation() {
        withAnimation {
            isAnimating = true
        }
        
        // Check if user has completed onboarding
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // Simulate loading time and then navigate
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if !hasCompletedOnboarding {
                showOnboarding = true
            } else if !authManager.isAuthenticated {
                showAuth = true
            } else {
                showMainApp = true
            }
        }
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
            .environmentObject(AuthManager.shared)
            .environmentObject(SettingsManager.shared)
    }
}