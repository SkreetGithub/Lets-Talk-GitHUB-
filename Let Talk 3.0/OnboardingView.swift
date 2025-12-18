import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showAuth = false
    
    private let pages = [
        OnboardingPage(
            title: "Welcome to Let Talk",
            subtitle: "Your AI-powered communication platform",
            image: "globe.americas.fill",
            description: "Connect with people around the world with real-time translation and seamless communication."
        ),
        OnboardingPage(
            title: "Real-time Translation",
            subtitle: "Break language barriers instantly",
            image: "translate",
            description: "Translate conversations in real-time with our advanced AI technology. Speak naturally and be understood by everyone."
        ),
        OnboardingPage(
            title: "Secure & Private",
            subtitle: "Your conversations are protected",
            image: "lock.shield.fill",
            description: "End-to-end encryption ensures your messages and calls remain private and secure."
        ),
        OnboardingPage(
            title: "Ready to Connect?",
            subtitle: "Join millions of users worldwide",
            image: "person.3.fill",
            description: "Start your journey with Let Talk and experience seamless global communication."
        )
    ]
    
    var body: some View {
        ZStack {
            // Background
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
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Bottom section
                VStack(spacing: 20) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }
                    
                    // Navigation buttons
                    HStack(spacing: 20) {
                        if currentPage > 0 {
                            Button("Previous") {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(25)
                        }
                        
                        Spacer()
                        
                        Button(currentPage == pages.count - 1 ? "Get Started" : "Next") {
                            if currentPage == pages.count - 1 {
                                completeOnboarding()
                            } else {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(25)
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.bottom, 50)
            }
        }
        .fullScreenCover(isPresented: $showAuth) {
            AuthView()
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        showAuth = true
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let image: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon
            Image(systemName: page.image)
                .font(.system(size: 80))
                .foregroundColor(.white)
                .padding(.bottom, 20)
            
            // Title
            Text(page.title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text(page.subtitle)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            
            // Description
            Text(page.description)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineLimit(nil)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}