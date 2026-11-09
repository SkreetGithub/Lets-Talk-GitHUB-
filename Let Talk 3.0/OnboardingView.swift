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
            description: "Your messages and calls travel over secure, encrypted connections."
        ),
        OnboardingPage(
            title: "Ready to Connect?",
            subtitle: "Connect with anyone, anywhere.",
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
                .animation(DS.screenTransition, value: currentPage)
                
                // Bottom section
                VStack(spacing: DS.spacingL) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.35))
                                .frame(width: index == currentPage ? 20 : 8, height: 8)
                                .animation(.spring(duration: 0.3), value: currentPage)
                        }
                    }
                    .frame(maxWidth: .infinity)   // dots centered on the screen, not on the button row
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Page \(currentPage + 1) of \(pages.count)")
                    
                    // Navigation: square Back button + full-width primary button, same height
                    HStack(spacing: DS.spacingS) {
                        if currentPage > 0 {
                            Button {
                                withAnimation(DS.screenTransition) { currentPage -= 1 }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: DS.primaryButtonHeight, height: DS.primaryButtonHeight)
                                    .background(Circle().fill(Color.white.opacity(0.2)))
                                    .contentShape(Circle())
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("Previous page")
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                        
                        Button {
                            if currentPage == pages.count - 1 {
                                completeOnboarding()
                            } else {
                                withAnimation(DS.screenTransition) { currentPage += 1 }
                            }
                        } label: {
                            Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                                .font(.headline)
                                .foregroundColor(Color(red: 0.80, green: 0.08, blue: 0.40))
                                .frame(maxWidth: .infinity)
                                .frame(height: DS.primaryButtonHeight)
                                .background(Capsule().fill(Color.white))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .animation(DS.screenTransition, value: currentPage)
                    .padding(.horizontal, DS.spacingL)
                }
                .padding(.bottom, DS.spacingXL)
            }
        }
        .fullScreenCover(isPresented: $showAuth) {
            // The single sign-up form (name, phone, email, password), opened in sign-up mode.
            EnhancedAuthView(startInSignUp: true)
                .environmentObject(AuthManager.shared)
                .environmentObject(SettingsManager.shared)
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
        VStack(spacing: DS.spacingXL) {
            Spacer()
            
            // Icon
            Image(systemName: page.image)
                .font(.system(size: 80))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.white)
                .frame(height: 100)                 // same icon box on every page, so text never jumps between pages
                .accessibilityHidden(true)
            
            // Text block: one shared horizontal inset for title, subtitle and description
            VStack(spacing: DS.spacingM) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(page.subtitle)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(page.description)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            
            Spacer()
            Spacer()   // weights content slightly above center, like Apple's own onboarding
        }
        .padding(.horizontal, DS.spacingXL)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}