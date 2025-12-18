import SwiftUI

struct BananaLoaderView: View {
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
            
            VStack(spacing: 30) {
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
                
                // Loading text
                Text("Saving your data...")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .opacity(isRotating ? 1.0 : 0.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0).delay(0.5),
                        value: isRotating
                    )
                
                // Progress indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .opacity(isRotating ? 1.0 : 0.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0).delay(1.0),
                        value: isRotating
                    )
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Start the gradient rotation animation
        withAnimation(
            Animation.linear(duration: animationDuration)
            .repeatForever(autoreverses: false)
        ) {
            gradientRotation = 360
        }
        
        // Start the emoji rotation animation
        withAnimation(
            Animation.linear(duration: animationDuration * 2)
            .repeatForever(autoreverses: false)
        ) {
            isRotating = true
        }
    }
}

