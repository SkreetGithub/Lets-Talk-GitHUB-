import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    
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
        // No navigation here: the app root (Let_Talk_3_0App) removes the splash and shows
        // Onboarding / Sign In / MainTabView. The splash used to present those itself on the
        // same 3-second timer, racing the root, and its MainTabView had no environment objects.
    }
    
    private func startAnimation() {
        withAnimation {
            isAnimating = true
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