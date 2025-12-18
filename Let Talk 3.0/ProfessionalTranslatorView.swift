import SwiftUI
import Speech
import AVFoundation
import Vision
import VisionKit
import PhotosUI

struct ProfessionalTranslatorView: View {
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
                    // Professional Header
                    UnifiedHeader(
                        title: "AI Translator",
                        subtitle: "Professional Translation Suite",
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

// MARK: - Photo Picker
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
            DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - Document Scanner View
struct DocumentScannerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        
        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 {
                parent.selectedImage = scan.imageOfPage(at: 0)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scanner failed with error: \(error)")
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
