import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showAuth = false
    /// The short animated intro plays first, then the feature cards slide in.
    @State private var showIntro = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let pages = [
        OnboardingPage(
            title: "Translate Calls",
            subtitle: "Voice and video, in real time",
            art: .calls,
            description: "Speak your language on a call. The other person hears and reads it in theirs."
        ),
        OnboardingPage(
            title: "Translate Messages",
            subtitle: "Text in your language",
            art: .messages,
            description: "Every message arrives in the reader's language, with the original one tap away."
        ),
        OnboardingPage(
            title: "Your Voice, Their Language",
            subtitle: "Choose how you sound",
            art: .voice,
            description: "Pick the voice people hear when your words are translated."
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
            
            if showIntro {
                OnboardingIntroView {
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.55, dampingFraction: 0.85)) {
                        showIntro = false
                    }
                }
                .transition(.opacity)
            } else {
                featureCards
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showAuth) {
            // The single sign-up form (name, phone, email, password), opened in sign-up mode.
            EnhancedAuthView(startInSignUp: true)
                .environmentObject(AuthManager.shared)
                .environmentObject(SettingsManager.shared)
        }
    }
    
    private var featureCards: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index], isActive: index == currentPage)
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
                        Haptics.tap()
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
                            .contentTransition(.opacity)
                    }
                    .buttonStyle(PressableStyle())
                }
                .animation(DS.screenTransition, value: currentPage)
                .padding(.horizontal, DS.spacingL)
            }
            .padding(.bottom, DS.spacingXL)
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        showAuth = true
    }
}

// MARK: - Animated intro (about 3 seconds)

/// Two people say hello in different languages, then a translation bubble appears between them.
/// Tap anywhere to skip.
struct OnboardingIntroView: View {
    let onFinish: () -> Void
    @State private var step = 0          // 1: first person speaks, 2: second person, 3: translation
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: DS.spacingXL) {
            Spacer()
            
            ZStack {
                HStack(alignment: .bottom) {
                    speaker(word: "Hello!", shown: step >= 1, bubbleOnLeft: false)
                    Spacer()
                    speaker(word: "¡Hola!", shown: step >= 2, bubbleOnLeft: true)
                }
                
                if step >= 3 {
                    HStack(spacing: DS.spacingS) {
                        Text("Hello")
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.subheadline.weight(.bold))
                        Text("Hola")
                    }
                    .font(.title3.weight(.bold))
                    .foregroundColor(Color(red: 0.80, green: 0.08, blue: 0.40))
                    .padding(.horizontal, DS.spacingL)
                    .padding(.vertical, DS.spacingM)
                    .background(Capsule().fill(Color.white))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    .offset(y: 16)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(height: 210)
            .padding(.horizontal, DS.spacingL)
            
            VStack(spacing: DS.spacingS) {
                Text("Let Talk")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Two languages. One conversation.")
                    .font(.system(size: 18, weight: .medium))
                    .opacity(0.9)
            }
            .foregroundColor(.white)
            .opacity(step >= 3 ? 1 : 0)
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Let Talk. Two languages, one conversation.")
        .accessibilityAddTraits(.isButton)
        .task { await play() }
    }
    
    private func speaker(word: String, shown: Bool, bubbleOnLeft: Bool) -> some View {
        VStack(alignment: bubbleOnLeft ? .trailing : .leading, spacing: DS.spacingS) {
            Text(word)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, DS.spacingM)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.22))
                )
                .scaleEffect(shown || reduceMotion ? 1 : 0.4, anchor: bubbleOnLeft ? .bottomTrailing : .bottomLeading)
                .opacity(shown ? 1 : 0)
            
            Image(systemName: "person.fill")
                .font(.system(size: 44))
                .foregroundColor(.white)
                .frame(width: 84, height: 84)
                .background(Circle().fill(Color.white.opacity(0.18)))
                .overlay(Circle().stroke(Color.white.opacity(shown ? 0.7 : 0.25), lineWidth: 2))
        }
    }
    
    private func play() async {
        let beats: [(UInt64, Int)] = [(350, 1), (800, 2), (800, 3)]
        for (delay, next) in beats {
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
            if Task.isCancelled || finished { return }
            if next == 3 { Haptics.soft() }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.65)) {
                step = next
            }
        }
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        if Task.isCancelled { return }
        finish()
    }
    
    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

// MARK: - Feature cards

struct OnboardingPage {
    enum Art { case calls, messages, voice }
    let title: String
    let subtitle: String
    let art: Art
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    var isActive: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: DS.spacingXL) {
            Spacer()
            
            // Illustration: same box on every page, so text never jumps between pages
            illustration
                .frame(height: 170)
                .scaleEffect(isActive || reduceMotion ? 1 : 0.88)
                .opacity(isActive ? 1 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isActive)
                .accessibilityHidden(true)
            
            // Text block: one shared horizontal inset for title, subtitle and description
            VStack(spacing: DS.spacingM) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
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
    
    @ViewBuilder private var illustration: some View {
        switch page.art {
        case .calls:
            ZStack {
                glassCircle(size: 150)
                Image(systemName: "video.fill")
                    .font(.system(size: 58))
                    .foregroundColor(.white)
                badge("captions.bubble.fill")
                    .offset(x: 62, y: -52)
                badge("phone.fill")
                    .offset(x: -64, y: 50)
            }
        case .messages:
            VStack(alignment: .leading, spacing: 10) {
                miniBubble("How are you?", outgoing: false)
                miniBubble("¿Cómo estás?", outgoing: true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: 230)
            .padding(DS.spacingM)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        case .voice:
            ZStack {
                glassCircle(size: 150)
                HStack(spacing: 14) {
                    Image(systemName: "person.wave.2.fill")
                        .font(.system(size: 46))
                        .foregroundColor(.white)
                    MiniWaveform()
                        .scaleEffect(1.8)
                }
                badge("globe")
                    .offset(x: 62, y: -52)
            }
        }
    }
    
    private func glassCircle(size: CGFloat) -> some View {
        Circle()
            .fill(Color.white.opacity(0.16))
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
    }
    
    private func badge(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(Color(red: 0.80, green: 0.08, blue: 0.40))
            .frame(width: 46, height: 46)
            .background(Circle().fill(Color.white))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
    
    private func miniBubble(_ text: String, outgoing: Bool) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(outgoing ? Color(red: 0.80, green: 0.08, blue: 0.40) : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(outgoing ? Color.white : Color.white.opacity(0.25))
            )
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}