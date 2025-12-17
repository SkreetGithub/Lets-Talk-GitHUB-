import SwiftUI

// MARK: - Enhanced Splash Screen
struct EnhancedSplashScreen: View {
    @Binding var isActive: Bool
    @State private var rocking = false
    @State private var showBananaLoader = false
    @State private var animationProgress: Double = 0.0

    var body: some View {
        ZStack {
            // Wave background effect
            WaveBackground()
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()
                
                if showBananaLoader {
                    BananaLoader(size: 120, animationDuration: 1.5)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Let's Talk")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding()
                        .rotationEffect(.degrees(rocking ? -5 : 5))
                        .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: rocking)
                        .onAppear {
                            rocking = true
                        }
                    
                    Image(systemName: "phone.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .modifier(VibrationEffect())
                }
                
                Spacer()
                
                // Progress indicator
                ProgressView(value: animationProgress, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 200)
                    .opacity(0.8)
            }
            .background(Color.clear)
            .onAppear {
                startAnimationSequence()
            }
        }
    }
    
    private func startAnimationSequence() {
        // Start with logo animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showBananaLoader = true
            }
        }
        
        // Progress animation
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            animationProgress += 2.0
            if animationProgress >= 100 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.5)) {
                    isActive = false
                }
            }
        }
    }
}

// Custom modifier for vibration effect
struct VibrationEffect: ViewModifier {
    @State private var isVibrating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVibrating ? 1.1 : 1.0)
            .rotationEffect(.degrees(isVibrating ? 5 : -5))
            .animation(Animation.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true), value: isVibrating)
            .onAppear {
                isVibrating = true
            }
    }
}

// Wave background effect
struct WaveBackground: View {
    @State private var waveOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<3) { index in
                    WaveShape()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.5), Color.blue]), startPoint: .top, endPoint: .bottom))
                        .offset(y: waveOffset + CGFloat(index) * 100)
                        .animation(Animation.linear(duration: 4).repeatForever(autoreverses: false), value: waveOffset)
                }
            }
            .onAppear {
                waveOffset = -geometry.size.height
            }
        }
    }
}

// Custom wave shape
struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height * 0.5))
        for x in stride(from: 0, through: width, by: 1) {
            let y = height * 0.5 + 20 * sin((x / width) * 2 * .pi * 2)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Banana Loader
struct BananaLoader: View {
    // Animation properties
    @State private var gradientRotation: Double = 0
    @State private var isRotating: Bool = false
    
    // Customization properties
    var size: CGFloat = 100
    var animationDuration: Double = 2.0
    var colors: [Color] = [
        .pink, .orange, .yellow, .green, .blue, .purple, .pink
    ]
    
    var body: some View {
        // The banana emoji with gradient mask
        Text("🍌")
            .font(.system(size: size))
            .overlay(
                // Gradient overlay that will be masked by the emoji
                LinearGradient(
                    gradient: Gradient(colors: colors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(gradientRotation))
                .mask(
                    Text("🍌")
                        .font(.system(size: size))
                )
            )
            // Optional rotation animation for the entire emoji
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .onAppear {
                // Start the animations
                withAnimation(
                    Animation.linear(duration: animationDuration)
                    .repeatForever(autoreverses: false)
                ) {
                    gradientRotation = 360
                }
            }
    }
}

#Preview {
    EnhancedSplashScreen(isActive: .constant(true))
}
