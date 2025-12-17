import SwiftUI

struct OfflineIndicatorView: View {
    @EnvironmentObject var dataPersistence: DataPersistenceManager
    @State private var showDetails = false
    
    var body: some View {
        if dataPersistence.isOfflineMode {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Offline Mode")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        showDetails.toggle()
                    }) {
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .onTapGesture {
                    showDetails.toggle()
                }
                
                if showDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("📱 Cached Data Available")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                        }
                        
                        HStack {
                            Text("🔄 Last Sync:")
                                .font(.system(size: 12))
                            Text(dataPersistence.lastSyncTime?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                        }
                        
                        HStack {
                            Text("💾 Cache Size:")
                                .font(.system(size: 12))
                            Text(dataPersistence.getCacheSize())
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                        }
                        
                        if dataPersistence.syncInProgress {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing...")
                                    .font(.system(size: 12))
                                Spacer()
                            }
                        } else {
                            Button(action: {
                                Task {
                                    await dataPersistence.syncWithFirebase()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12))
                                    Text("Sync Now")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .background(Color(.systemGray6))
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct OfflineIndicatorModifier: ViewModifier {
    @EnvironmentObject var dataPersistence: DataPersistenceManager
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            OfflineIndicatorView()
                .environmentObject(dataPersistence)
            
            content
        }
    }
}

extension View {
    func offlineIndicator() -> some View {
        modifier(OfflineIndicatorModifier())
    }
}

// MARK: - Offline Settings View
struct OfflineSettingsView: View {
    @EnvironmentObject var dataPersistence: DataPersistenceManager
    @State private var showingClearCacheAlert = false
    @State private var showingExportData = false
    @State private var showingImportData = false
    @State private var exportData: Data?
    
    var body: some View {
        NavigationView {
            List {
                Section("Offline Mode") {
                    HStack {
                        Image(systemName: dataPersistence.isOfflineMode ? "wifi.slash" : "wifi")
                            .foregroundColor(dataPersistence.isOfflineMode ? .orange : .green)
                        
                        VStack(alignment: .leading) {
                            Text(dataPersistence.isOfflineMode ? "Offline Mode" : "Online Mode")
                                .font(.headline)
                            Text(dataPersistence.isOfflineMode ? "Using cached data" : "Connected to server")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { dataPersistence.isOfflineMode },
                            set: { isOn in
                                if isOn {
                                    dataPersistence.enableOfflineMode()
                                } else {
                                    dataPersistence.disableOfflineMode()
                                }
                            }
                        ))
                    }
                }
                
                Section("Sync Status") {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text(dataPersistence.lastSyncTime?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Sync Status")
                        Spacer()
                        if dataPersistence.syncInProgress {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing...")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Ready")
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await dataPersistence.syncWithFirebase()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync Now")
                        }
                    }
                    .disabled(dataPersistence.syncInProgress)
                }
                
                Section("Cache Information") {
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text(dataPersistence.getCacheSize())
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        dataPersistence.clearExpiredCache()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Expired Cache")
                        }
                        .foregroundColor(.orange)
                    }
                    
                    Button(action: {
                        showingClearCacheAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Clear All Cache")
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("Data Management") {
                    Button(action: {
                        exportData = dataPersistence.exportUserData()
                        showingExportData = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Data")
                        }
                    }
                    
                    Button(action: {
                        showingImportData = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Data")
                        }
                    }
                }
            }
            .navigationTitle("Offline Settings")
            .alert("Clear All Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    dataPersistence.clearAllCache()
                }
            } message: {
                Text("This will remove all cached data. You'll need to sync again to restore your data.")
            }
            .sheet(isPresented: $showingExportData) {
                if let data = exportData {
                    OfflineShareSheet(activityItems: [data])
                }
            }
            .sheet(isPresented: $showingImportData) {
                DocumentPicker { url in
                    if let data = try? Data(contentsOf: url) {
                        let success = dataPersistence.importUserData(data)
                        if success {
                            // Show success message
                        } else {
                            // Show error message
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct OfflineShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
        }
    }
}

#Preview {
    OfflineSettingsView()
        .environmentObject(DataPersistenceManager.shared)
}
