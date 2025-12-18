import SwiftUI
import PhotosUI

// MARK: - Keyboard Dismissal Modifier
struct KeyboardDismissalModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        modifier(KeyboardDismissalModifier())
    }
}

// MARK: - Unified Language Button
struct UnifiedLanguageButton: View {
    let language: UnifiedTranslationLanguage
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(language.flag)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(language.code.uppercased())
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Unified Text Input Card
struct UnifiedTextInputCard: View {
    @Binding var text: String
    let placeholder: String
    let isProcessing: Bool
    let onClear: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(placeholder)
                    .font(.headline)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Spacer()
                
                if isProcessing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                        Text("Processing...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                    )
                }
                
                if !text.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.title3)
                    }
                }
            }
            
            ZStack {
                TextEditor(text: $text)
                    .frame(height: 120)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .foregroundColor(.white)
                
                if isProcessing {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.4))
                        .frame(height: 120)
                        .overlay(
                            VStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                Text("Processing...")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Unified Control Button
struct UnifiedControlButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let isProcessing: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(width: 70, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive ? Color.green.opacity(0.8) : Color.white.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isActive ? 1.1 : 1.0)
            .animation(
                isActive ? 
                Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                Animation.easeInOut(duration: 0.3),
                value: isActive
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .disabled(isProcessing)
    }
}

// MARK: - Unified Translate Button
struct UnifiedTranslateButton: View {
    let isTranslating: Bool
    let canTranslate: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isTranslating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                Text("Translate")
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(canTranslate ? Color.blue.opacity(0.8) : Color.gray.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .foregroundColor(.white)
        .disabled(!canTranslate || isTranslating)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Unified Language Selection Card
struct UnifiedLanguageSelectionCard: View {
    let sourceLanguage: UnifiedTranslationLanguage
    let targetLanguage: UnifiedTranslationLanguage
    let onSourceLanguageTap: () -> Void
    let onTargetLanguageTap: () -> Void
    let onSwapLanguages: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Language Selection")
                    .font(.headline)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                // Source Language
                UnifiedLanguageButton(
                    language: sourceLanguage,
                    isSelected: false,
                    action: onSourceLanguageTap
                )
                
                // Swap Button
                Button(action: onSwapLanguages) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Swap")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                
                // Target Language
                UnifiedLanguageButton(
                    language: targetLanguage,
                    isSelected: false,
                    action: onTargetLanguageTap
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Unified Translation Controls Card
struct UnifiedTranslationControlsCard: View {
    let isRecording: Bool
    let isSpeakerOn: Bool
    let isProcessingImage: Bool
    let onVoiceTap: () -> Void
    let onScanTap: () -> Void
    let onPhotoTap: () -> Void
    let onTranslate: () -> Void
    let onSpeakerTap: () -> Void
    let canTranslate: Bool
    let isTranslating: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // First Row - Input Methods
            HStack(spacing: 16) {
                UnifiedControlButton(
                    icon: isRecording ? "mic.fill" : "mic",
                    title: "Voice",
                    isActive: isRecording,
                    isProcessing: false,
                    action: onVoiceTap
                )
                
                UnifiedControlButton(
                    icon: "doc.text.viewfinder",
                    title: "Scan",
                    isActive: false,
                    isProcessing: isProcessingImage,
                    action: onScanTap
                )
                
                UnifiedControlButton(
                    icon: "photo.fill",
                    title: "Photos",
                    isActive: false,
                    isProcessing: false,
                    action: onPhotoTap
                )
            }
            
            // Second Row - Translate and Speaker
            HStack(spacing: 16) {
                UnifiedTranslateButton(
                    isTranslating: isTranslating,
                    canTranslate: canTranslate,
                    action: onTranslate
                )
                
                UnifiedControlButton(
                    icon: isSpeakerOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    title: "Speak",
                    isActive: isSpeakerOn,
                    isProcessing: false,
                    action: onSpeakerTap
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Unified Translation Result Card
struct UnifiedTranslationResultCard: View {
    let translatedText: String
    let onCopy: () -> Void
    let onFavorite: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Translation")
                    .font(.headline)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Spacer()
                
                if !translatedText.isEmpty {
                    HStack(spacing: 12) {
                        Button(action: onCopy) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.title3)
                        }
                        
                        Button(action: onFavorite) {
                            Image(systemName: "heart")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.title3)
                        }
                        
                        Button(action: onShare) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.title3)
                        }
                    }
                }
            }
            
            ScrollView {
                Text(translatedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .foregroundColor(.white)
            }
            .frame(minHeight: 120, maxHeight: 200)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Unified Header
struct UnifiedHeader: View {
    let title: String
    let subtitle: String
    let isTranslating: Bool
    let sourceLanguage: UnifiedTranslationLanguage
    let targetLanguage: UnifiedTranslationLanguage
    let onHistoryTap: () -> Void
    let onFavoritesTap: () -> Void
    let onSettingsTap: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe.americas.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                    }
                    
                    // Status indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isTranslating ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        Text(isTranslating ? "Translating..." : "Ready to translate")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        // Language pair indicator
                        Text("\(sourceLanguage.code.uppercased()) → \(targetLanguage.code.uppercased())")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            )
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // History button
                    Button(action: onHistoryTap) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            )
                    }
                    
                    // Favorites button
                    Button(action: onFavoritesTap) {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            )
                    }
                    
                    // Settings button
                    Button(action: onSettingsTap) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            )
                    }
                }
            }
        }
        .padding(.top, 10)
    }
}

// MARK: - Unified Background
struct UnifiedBackground: View {
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.6),
                    Color.pink.opacity(0.4),
                    Color.orange.opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated particles
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: CGFloat.random(in: 4...12))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .animation(
                        Animation.linear(duration: Double.random(in: 10...20))
                            .repeatForever(autoreverses: false),
                        value: UUID()
                    )
            }
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
