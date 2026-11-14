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
    @State private var scannedImage: UIImage?
    @State private var showHistory = false
    @State private var showFavorites = false
    @State private var selectedImage: UIImage?
    @State private var showCameraDenied = false
    
    var body: some View {
        ZStack {
            // Unified Background
            UnifiedBackground()
            
            // Main Content
            ScrollView {
                VStack(spacing: DS.spacingL) {
                    // Professional Header
                    UnifiedHeader(
                        title: "AI Translator",
                        subtitle: "Professional Translation Suite",
                        isTranslating: viewModel.isTranslating,
                        sourceLanguage: viewModel.sourceLanguage,
                        targetLanguage: viewModel.targetLanguage,
                        onHistoryTap: { present { showHistory = true } },
                        onFavoritesTap: { present { showFavorites = true } },
                        onSettingsTap: { present { showSettings = true } }
                    )
                    
                    // Language Selection Card
                    UnifiedLanguageSelectionCard(
                        sourceLanguage: viewModel.sourceLanguage,
                        targetLanguage: viewModel.targetLanguage,
                        onSourceLanguageTap: {
                            isSelectingSource = true
                            present { showLanguageSelector = true }
                        },
                        onTargetLanguageTap: {
                            isSelectingSource = false
                            present { showLanguageSelector = true }
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
                        onVoiceTap: {
                            KeyboardDismisser.dismiss()
                            viewModel.toggleRecording()
                        },
                        onScanTap: { present { showScanOptions = true } },
                        onPhotoTap: { present { showImagePicker = true } },
                        onTranslate: {
                            KeyboardDismisser.dismiss()
                            viewModel.translate()
                        },
                        onSpeakerTap: viewModel.toggleSpeaker,
                        canTranslate: viewModel.canTranslate,
                        isTranslating: viewModel.isTranslating
                    )
                    
                    // Translation Result Card
                    UnifiedTranslationResultCard(
                        translatedText: viewModel.translatedText,
                        isFavorite: viewModel.isCurrentTranslationFavorite,
                        onCopy: {
                            UIPasteboard.general.string = viewModel.translatedText
                            Haptics.success()
                        },
                        onFavorite: viewModel.addToFavorites
                    )
                }
                .padding(.horizontal, DS.spacingM)
                .padding(.bottom, 140)   // clears the floating tab bar + page dots so the last card can scroll fully into view
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showSettings) {
            TranslatorSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showLanguageSelector) {
            UnifiedLanguageSelectorView(
                selectedLanguage: isSelectingSource ? $viewModel.sourceLanguage : $viewModel.targetLanguage,
                isPresented: $showLanguageSelector,
                isSourceLanguage: isSelectingSource,
                onLanguageSelected: { _ in }
            )
        }
        .sheet(isPresented: $showDocumentScanner) {
            DocumentScannerView(selectedImage: $scannedImage)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(selectedImage: $scannedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showHistory) {
            TranslatorHistorySheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showFavorites) {
            FavoriteLanguagesView(viewModel: viewModel)
        }
        .confirmationDialog("Scan Text", isPresented: $showScanOptions, titleVisibility: .visible) {
            Button("Scan Document") { openCamera(document: true) }
            Button("Take Photo") { openCamera(document: false) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Point the camera at printed text. Let Talk reads it and puts it in the box to translate.")
        }
        .alert("Camera Access Needed", isPresented: $showCameraDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Let Talk needs the camera to scan text. Turn on Camera for Let Talk in Settings.")
        }
        .alert("Translator", isPresented: Binding(
            get: { !viewModel.errorMessage.isEmpty },
            set: { if !$0 { viewModel.errorMessage = "" } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: scannedImage) { _, image in
            if let image {
                viewModel.processImage(image)
                scannedImage = nil
            }
        }
        .onChange(of: selectedImage) { _, image in
            if let image {
                viewModel.processImage(image)
                selectedImage = nil
            }
        }
        .onDisappear {
            // Leaving the tab: don't keep listening or talking in the background.
            viewModel.stopRecording()
            viewModel.stopSpeaking()
        }
    }
    
    /// Closes the keyboard before opening a sheet, so it doesn't stay stuck behind it.
    private func present(_ open: () -> Void) {
        KeyboardDismisser.dismiss()
        open()
    }
    
    /// Asks for camera permission first (the prompt appears once); explains how to fix a denial.
    private func openCamera(document: Bool) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            viewModel.errorMessage = "This device has no camera available."
            return
        }
        let start = {
            if document && VNDocumentCameraViewController.isSupported {
                showDocumentScanner = true
            } else {
                showCamera = true
            }
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { start() } else { showCameraDenied = true }
                }
            }
        default:
            showCameraDenied = true
        }
    }
}

// MARK: - Favorite Languages (heart)

/// The five languages used most, plus saved translations. Tap a language to translate into it.
struct FavoriteLanguagesView: View {
    @ObservedObject var viewModel: UnifiedTranslationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(Array(viewModel.topLanguages.enumerated()), id: \.element.code) { index, language in
                        Button {
                            viewModel.useLanguage(language)
                            Haptics.tap()
                            dismiss()
                        } label: {
                            HStack(spacing: DS.spacingM) {
                                Text("\(index + 1)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                FlagView(flag: language.flag, height: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(language.name)
                                        .foregroundColor(.primary)
                                    Text(usageText(for: language))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if language.code == viewModel.targetLanguage.code {
                                    Text("Current")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Top 5 Languages")
                } footer: {
                    Text("Based on the languages you translate with most. Tap one to translate into it.")
                }
                
                Section("Saved Translations") {
                    if viewModel.favoriteTranslations.isEmpty {
                        Text("Tap the heart on a translation to save it here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.favoriteTranslations) { translation in
                            Button {
                                viewModel.restore(translation)
                                dismiss()
                            } label: {
                                TranslationRow(translation: translation)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            offsets.map { viewModel.favoriteTranslations[$0] }.forEach(viewModel.removeFromFavorites)
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func usageText(for language: UnifiedTranslationLanguage) -> String {
        let count = viewModel.usageCount(for: language)
        return count == 0 ? "Suggested" : "Used in your translations"
    }
}

// MARK: - Translator Settings (gear)

struct TranslatorSettingsView: View {
    @ObservedObject var viewModel: UnifiedTranslationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pickingSource = false
    @State private var pickingTarget = false
    @State private var showVoiceSettings = false
    @State private var confirmClearHistory = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Default Languages") {
                    languageRow(title: "Translate From", language: viewModel.sourceLanguage) { pickingSource = true }
                    languageRow(title: "Translate To", language: viewModel.targetLanguage) { pickingTarget = true }
                    Button {
                        viewModel.swapLanguages()
                    } label: {
                        Label("Swap Languages", systemImage: "arrow.left.arrow.right")
                    }
                }
                
                Section {
                    ForEach(viewModel.languagePresets) { preset in
                        Button {
                            viewModel.applyPreset(preset)
                            Haptics.tap()
                        } label: {
                            HStack {
                                FlagView(flag: preset.sourceLanguage.flag, height: 18)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                FlagView(flag: preset.targetLanguage.flag, height: 18)
                                Text(preset.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if preset.sourceLanguage.code == viewModel.sourceLanguage.code &&
                                    preset.targetLanguage.code == viewModel.targetLanguage.code {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { viewModel.languagePresets[$0] }.forEach(viewModel.removePreset)
                    }
                    Button {
                        let name = "\(viewModel.sourceLanguage.name) → \(viewModel.targetLanguage.name)"
                        guard !viewModel.languagePresets.contains(where: { $0.name == name }) else { return }
                        viewModel.addPreset(name: name, sourceLanguage: viewModel.sourceLanguage, targetLanguage: viewModel.targetLanguage)
                    } label: {
                        Label("Save Current Pair", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Quick Pairs")
                } footer: {
                    Text("Tap a pair to use it. Swipe left to remove one.")
                }
                
                Section {
                    Toggle("Speak Translations Automatically", isOn: $viewModel.autoSpeak)
                    Button {
                        showVoiceSettings = true
                    } label: {
                        Label("Voice", systemImage: "person.wave.2")
                    }
                } header: {
                    Text("Speech")
                } footer: {
                    Text("Translations are read aloud in your Let Talk voice.")
                }
                
                Section {
                    Button("Clear Translation History", role: .destructive) {
                        confirmClearHistory = true
                    }
                    .disabled(viewModel.recentTranslations.isEmpty)
                }
            }
            .navigationTitle("Translator Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $pickingSource) {
                UnifiedLanguageSelectorView(selectedLanguage: $viewModel.sourceLanguage, isPresented: $pickingSource,
                                            isSourceLanguage: true, onLanguageSelected: { _ in })
            }
            .sheet(isPresented: $pickingTarget) {
                UnifiedLanguageSelectorView(selectedLanguage: $viewModel.targetLanguage, isPresented: $pickingTarget,
                                            isSourceLanguage: false, onLanguageSelected: { _ in })
            }
            .sheet(isPresented: $showVoiceSettings) {
                VoiceSettingsView()
            }
            .confirmationDialog("Clear all translation history?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { viewModel.clearHistory() }
            }
        }
    }
    
    private func languageRow(title: String, language: UnifiedTranslationLanguage, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                FlagView(flag: language.flag, height: 18)
                Text(language.name)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - History (clock)

struct TranslatorHistorySheet: View {
    @ObservedObject var viewModel: UnifiedTranslationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.recentTranslations.isEmpty {
                    ContentUnavailableView("No Translations Yet", systemImage: "clock.arrow.circlepath",
                                           description: Text("Your translations will appear here."))
                } else {
                    List {
                        ForEach(viewModel.recentTranslations) { translation in
                            Button {
                                viewModel.restore(translation)
                                dismiss()
                            } label: {
                                TranslationRow(translation: translation)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear", role: .destructive) { viewModel.clearHistory() }
                        .disabled(viewModel.recentTranslations.isEmpty)
                }
            }
        }
    }
}

/// One past or saved translation in a list.
struct TranslationRow: View {
    let translation: UnifiedTranslationHistory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(translation.sourceText)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(3)
            Text(translation.translatedText)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            HStack {
                Text("\(translation.sourceLanguage.code.uppercased()) → \(translation.targetLanguage.code.uppercased())")
                Spacer()
                Text(translation.timestamp, style: .relative)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Camera (Take Photo)
struct CameraCaptureView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
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
            debugLog("Document scanner failed with error: \(error)")
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
