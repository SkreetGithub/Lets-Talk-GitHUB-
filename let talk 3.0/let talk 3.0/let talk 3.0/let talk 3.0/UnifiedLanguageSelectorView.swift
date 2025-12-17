import SwiftUI

struct UnifiedLanguageSelectorView: View {
    @Binding var selectedLanguage: UnifiedTranslationLanguage
    @Binding var isPresented: Bool
    let isSourceLanguage: Bool
    let onLanguageSelected: (UnifiedTranslationLanguage) -> Void
    
    @State private var searchText = ""
    @State private var showPopularOnly = true
    
    private var filteredLanguages: [UnifiedTranslationLanguage] {
        let languages = showPopularOnly ? 
            UnifiedTranslationLanguage.allLanguages.filter { $0.isPopular } :
            UnifiedTranslationLanguage.allLanguages
        
        if searchText.isEmpty {
            return languages
        } else {
            return languages.filter { language in
                language.name.localizedCaseInsensitiveContains(searchText) ||
                language.code.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search languages...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Filter Toggle
                HStack {
                    Toggle("Popular Languages Only", isOn: $showPopularOnly)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Languages List
                List {
                    ForEach(filteredLanguages) { language in
                        LanguageRowView(
                            language: language,
                            isSelected: language.id == selectedLanguage.id,
                            onTap: {
                                selectedLanguage = language
                                onLanguageSelected(language)
                                isPresented = false
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle(isSourceLanguage ? "Source Language" : "Target Language")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                }
            )
        }
    }
}

struct LanguageRowView: View {
    let language: UnifiedTranslationLanguage
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(language.flag)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(language.code.uppercased())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Language Presets View
struct LanguagePresetsView: View {
    @ObservedObject var viewModel: UnifiedTranslationViewModel
    @Binding var isPresented: Bool
    @State private var showingAddPreset = false
    @State private var newPresetName = ""
    @State private var selectedSourceLanguage = UnifiedTranslationLanguage.english
    @State private var selectedTargetLanguage = UnifiedTranslationLanguage.spanish
    
    var body: some View {
        NavigationView {
            List {
                Section("Quick Presets") {
                    ForEach(viewModel.languagePresets) { preset in
                        PresetRowView(
                            preset: preset,
                            onTap: {
                                viewModel.applyPreset(preset)
                                isPresented = false
                            },
                            onDelete: {
                                viewModel.removePreset(preset)
                            }
                        )
                    }
                }
                
                Section("Popular Combinations") {
                    ForEach(popularCombinations, id: \.name) { combination in
                        Button(action: {
                            viewModel.sourceLanguage = combination.sourceLanguage
                            viewModel.targetLanguage = combination.targetLanguage
                            isPresented = false
                        }) {
                            HStack {
                                Text(combination.sourceLanguage.flag)
                                Text("→")
                                Text(combination.targetLanguage.flag)
                                Text(combination.name)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("Language Presets")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Add Preset") {
                    showingAddPreset = true
                }
            )
            .sheet(isPresented: $showingAddPreset) {
                AddPresetView(
                    viewModel: viewModel,
                    isPresented: $showingAddPreset
                )
            }
        }
    }
    
    private var popularCombinations: [(name: String, sourceLanguage: UnifiedTranslationLanguage, targetLanguage: UnifiedTranslationLanguage)] {
        [
            ("English → Spanish", .english, .spanish),
            ("Spanish → English", .spanish, .english),
            ("English → French", .english, UnifiedTranslationLanguage.allLanguages.first { $0.code == "fr" }!),
            ("English → German", .english, UnifiedTranslationLanguage.allLanguages.first { $0.code == "de" }!),
            ("English → Chinese", .english, UnifiedTranslationLanguage.allLanguages.first { $0.code == "zh" }!),
            ("English → Japanese", .english, UnifiedTranslationLanguage.allLanguages.first { $0.code == "ja" }!),
            ("English → Korean", .english, UnifiedTranslationLanguage.allLanguages.first { $0.code == "ko" }!),
            ("English → Arabic", .english, UnifiedTranslationLanguage.allLanguages.first { $0.code == "ar" }!)
        ]
    }
}

struct PresetRowView: View {
    let preset: LanguagePreset
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(preset.sourceLanguage.flag)
                Text("→")
                Text(preset.targetLanguage.flag)
                Text(preset.name)
                    .foregroundColor(.primary)
                Spacer()
                if preset.isDefault {
                    Text("Default")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !preset.isDefault {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }
        }
    }
}

struct AddPresetView: View {
    @ObservedObject var viewModel: UnifiedTranslationViewModel
    @Binding var isPresented: Bool
    @State private var presetName = ""
    @State private var selectedSourceLanguage = UnifiedTranslationLanguage.english
    @State private var selectedTargetLanguage = UnifiedTranslationLanguage.spanish
    @State private var showingSourceSelector = false
    @State private var showingTargetSelector = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Preset Name") {
                    TextField("Enter preset name", text: $presetName)
                }
                
                Section("Source Language") {
                    Button(action: { showingSourceSelector = true }) {
                        HStack {
                            Text(selectedSourceLanguage.flag)
                            Text(selectedSourceLanguage.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Target Language") {
                    Button(action: { showingTargetSelector = true }) {
                        HStack {
                            Text(selectedTargetLanguage.flag)
                            Text(selectedTargetLanguage.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Preset")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    savePreset()
                }
                .disabled(presetName.isEmpty)
            )
            .sheet(isPresented: $showingSourceSelector) {
                UnifiedLanguageSelectorView(
                    selectedLanguage: $selectedSourceLanguage,
                    isPresented: $showingSourceSelector,
                    isSourceLanguage: true,
                    onLanguageSelected: { _ in }
                )
            }
            .sheet(isPresented: $showingTargetSelector) {
                UnifiedLanguageSelectorView(
                    selectedLanguage: $selectedTargetLanguage,
                    isPresented: $showingTargetSelector,
                    isSourceLanguage: false,
                    onLanguageSelected: { _ in }
                )
            }
        }
    }
    
    private func savePreset() {
        viewModel.addPreset(
            name: presetName,
            sourceLanguage: selectedSourceLanguage,
            targetLanguage: selectedTargetLanguage
        )
        isPresented = false
    }
}
