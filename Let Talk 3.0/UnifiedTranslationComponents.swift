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
            // Vertical tile: flag, name, code. Side-by-side layout left ~38pt for the
            // name, which broke "English" into "En/gli/sh".
            VStack(spacing: DS.spacingXS) {
                FlagView(flag: language.flag, height: 26)
                
                Text(language.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(language.code.uppercased())
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, minHeight: 96)   // both tiles always the same height
            .padding(.horizontal, DS.spacingS)
            .background(
                RoundedRectangle(cornerRadius: DS.cornerRadiusS)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadiusS)
                            .stroke(isSelected ? Color.blue : Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .padding(DS.spacingS)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: DS.cornerRadiusS))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(language.name). Tap to change language")
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
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)   // keep the glass look; white text was invisible on the default white box
                    .font(.body)
                    .frame(minHeight: 120)
                    .padding(DS.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: DS.cornerRadiusM)
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadiusM)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .foregroundColor(.white)
                    .accessibilityLabel("Text to translate")
                
                // Placeholder. TextEditor has none; offsets match its built-in text insets (5pt / 8pt).
                if text.isEmpty && !isProcessing {
                    Text("Type or paste text to translate...")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, DS.spacingM + 5)
                        .padding(.vertical, DS.spacingM + 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                
                if isProcessing {
                    RoundedRectangle(cornerRadius: DS.cornerRadiusM)
                        .fill(Color.black.opacity(0.4))
                        .frame(maxWidth: .infinity, minHeight: 120 + DS.spacingM * 2)
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
        .buttonStyle(PressableStyle())
        .accessibilityLabel(title)
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
            .frame(maxWidth: .infinity)
            .frame(height: 70)                       // same height as the Speak button beside it
            .background(
                RoundedRectangle(cornerRadius: DS.cornerRadiusM)
                    .fill(canTranslate ? Color.blue.opacity(0.8) : Color.gray.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadiusM)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.cornerRadiusM))
            .animation(.easeInOut(duration: 0.2), value: isTranslating)
        }
        .buttonStyle(PressableStyle())
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
            
            HStack(spacing: DS.spacingS) {
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
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Swap languages")
                
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
            HStack(spacing: DS.spacingM) {
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
            HStack(spacing: DS.spacingM) {
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
        VStack(alignment: .leading, spacing: DS.spacingM) {
            // Row 1: icon + title. Full width, so "AI Translator" stays on one line.
            HStack(alignment: .center, spacing: DS.spacingM) {
                Image(systemName: "globe.americas.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                
                Spacer(minLength: 0)
            }
            
            // Row 2: status + language pair on the left, actions on the right.
            HStack(spacing: DS.spacingS) {
                Circle()
                    .fill(isTranslating ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Text(isTranslating ? "Translating..." : "Ready to translate")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .fixedSize()
                
                Text("\(sourceLanguage.code.uppercased()) → \(targetLanguage.code.uppercased())")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, DS.spacingS)
                    .padding(.vertical, DS.spacingXS)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    )
                
                Spacer(minLength: DS.spacingS)
                
                headerButton("clock.arrow.circlepath", label: "Translation history", action: onHistoryTap)
                headerButton("heart.fill", label: "Favorites", action: onFavoritesTap)
                headerButton("gearshape.fill", label: "Translator settings", action: onSettingsTap)
            }
        }
        .padding(.top, DS.spacingL)   // breathing room below the nav bar; title no longer touches the gradient edge
    }
    
    private func headerButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: DS.minTapTarget, height: DS.minTapTarget)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
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
            
            // Static particles. Positions are derived from the index, so they no longer jump
            // to new random spots every time the screen re-renders (e.g. on each keystroke).
            GeometryReader { geo in
                ForEach(0..<20, id: \.self) { index in
                    let fx = CGFloat((index * 37 + 11) % 100) / 100
                    let fy = CGFloat((index * 61 + 23) % 100) / 100
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: CGFloat(4 + (index * 7) % 9))
                        .position(x: fx * geo.size.width, y: fy * geo.size.height)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
