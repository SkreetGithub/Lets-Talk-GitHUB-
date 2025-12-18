import SwiftUI
import Speech
import AVFoundation
import Vision
import VisionKit

struct TranslatorView: View {
    @StateObject private var viewModel = UnifiedTranslationViewModel()
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var authManager: AuthManager
    @State private var showLanguageSelector = false
    @State private var isSelectingSource = true
    @State private var showImagePicker = false
    @State private var showScanOptions = false
    @State private var showCamera = false
    @State private var showDocumentScanner = false
    @State private var showSettings = false
    @State private var showSignOutAlert = false
    @State private var scannedImage: UIImage?
    @State private var showHistory = false
    @State private var showFavorites = false
    @State private var showLanguagePresets = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        ZStack {
            // Unified Background
            UnifiedBackground()
            
            // Main Content
            ScrollView {
                VStack(spacing: 24) {
                    // Standard Header
                    UnifiedHeader(
                        title: "Translator",
                        subtitle: "AI-Powered Real-time Translation",
                        isTranslating: viewModel.isTranslating,
                        sourceLanguage: viewModel.sourceLanguage,
                        targetLanguage: viewModel.targetLanguage,
                        onHistoryTap: { showHistory = true },
                        onFavoritesTap: { showFavorites = true },
                        onSettingsTap: { showSettings = true }
                    )
                    
                    // Language Selection Card
                    UnifiedLanguageSelectionCard(
                        sourceLanguage: viewModel.sourceLanguage,
                        targetLanguage: viewModel.targetLanguage,
                        onSourceLanguageTap: {
                            isSelectingSource = true
                            showLanguageSelector = true
                        },
                        onTargetLanguageTap: {
                            isSelectingSource = false
                            showLanguageSelector = true
                        },
                        onSwapLanguages: viewModel.swapLanguages
                    )
                    
                    // Translation Input Card
                    UnifiedTextInputCard(
                        text: $viewModel.sourceText,
                        placeholder: "Enter text",
                        isProcessing: viewModel.isProcessingImage,
                        onClear: viewModel.clearSourceText
                    )
                    
                    // Translation Controls Card
                    UnifiedTranslationControlsCard(
                        isRecording: viewModel.isRecording,
                        isSpeakerOn: viewModel.isSpeakerOn,
                        isProcessingImage: viewModel.isProcessingImage,
                        onVoiceTap: viewModel.toggleRecording,
                        onScanTap: { showScanOptions = true },
                        onPhotoTap: { showImagePicker = true },
                        onTranslate: viewModel.translate,
                        onSpeakerTap: viewModel.toggleSpeaker,
                        canTranslate: viewModel.canTranslate,
                        isTranslating: viewModel.isTranslating
                    )
                    
                    // Translation Result Card
                    UnifiedTranslationResultCard(
                        translatedText: viewModel.translatedText,
                        onCopy: {
                            UIPasteboard.general.string = viewModel.translatedText
                        },
                        onFavorite: viewModel.addToFavorites,
                        onShare: {
                            // Share functionality
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .dismissKeyboardOnTap()
        .sheet(isPresented: $showSettings) {
            UnifiedSettingsView(translationViewModel: viewModel)
        }
        .sheet(isPresented: $showLanguageSelector) {
            UnifiedLanguageSelectorView(
                selectedLanguage: isSelectingSource ? $viewModel.sourceLanguage : $viewModel.targetLanguage,
                isPresented: $showLanguageSelector,
                isSourceLanguage: isSelectingSource,
                onLanguageSelected: { _ in }
            )
        }
        .sheet(isPresented: $showLanguagePresets) {
            LanguagePresetsView(
                viewModel: viewModel,
                isPresented: $showLanguagePresets
            )
        }
        .sheet(isPresented: $showDocumentScanner) {
            DocumentScannerView(selectedImage: $scannedImage)
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showHistory) {
            TranslationHistoryView(translations: viewModel.recentTranslations)
        }
        .sheet(isPresented: $showFavorites) {
            TranslationFavoritesView(favorites: viewModel.favoriteTranslations)
        }
        .actionSheet(isPresented: $showScanOptions) {
            ActionSheet(
                title: Text("Scan Options"),
                message: Text("Choose how to capture text"),
                buttons: [
                    .default(Text("Document Scanner")) {
                        showDocumentScanner = true
                    },
                    .default(Text("Camera")) {
                        showCamera = true
                    },
                    .cancel()
                ]
            )
        }
        .onChange(of: scannedImage) { image in
            if let image = image {
                viewModel.processImage(image)
            }
        }
        .onChange(of: selectedImage) { image in
            if let image = image {
                viewModel.processImage(image)
            }
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    try await authManager.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if !isAuthenticated {
                dismiss()
            }
        }
    }
    
    // MARK: - Helper Methods
    private func dismiss() {
        // Dismiss implementation
    }
}