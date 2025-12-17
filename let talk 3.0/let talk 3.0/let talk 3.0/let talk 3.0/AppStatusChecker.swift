import Foundation
import SwiftUI
import Network
import LocalAuthentication

// MARK: - App Status Checker
class AppStatusChecker: ObservableObject {
    static let shared = AppStatusChecker()
    
    @Published var isProductionReady = false
    @Published var hasDemoData = false
    @Published var networkStatus = "Unknown"
    @Published var firebaseStatus = "Unknown" // legacy name; now reflects Supabase backend status
    @Published var biometricStatus = "Unknown"
    @Published var storageStatus = "Unknown"
    @Published var issues: [String] = []
    
    private init() {
        checkAppStatus()
    }
    
    func checkAppStatus() {
        checkDemoData()
        checkNetworkStatus()
        checkFirebaseStatus()
        checkBiometricStatus()
        checkStorageStatus()
        validateProductionReadiness()
    }
    
    private func checkDemoData() {
        hasDemoData = ProductionCleanupService.shared.containsDemoData()
    }
    
    private func checkNetworkStatus() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkStatus")
        
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.networkStatus = path.status == .satisfied ? "Connected" : "Disconnected"
            }
        }
        
        monitor.start(queue: queue)
        
        // Stop monitoring after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            monitor.cancel()
        }
    }
    
    private func checkFirebaseStatus() {
        // Firebase has been removed; check whether Supabase is configured.
        let isConfigured =
            !Config.supabaseAnonKey.isEmpty &&
            !Config.supabaseURLString.isEmpty &&
            !Config.supabaseAnonKey.hasPrefix("YOUR_") &&
            !Config.supabaseURLString.contains("YOUR_PROJECT_REF")
        firebaseStatus = isConfigured ? "Supabase Configured" : "Supabase Not Configured"
    }
    
    private func checkBiometricStatus() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricStatus = "Face ID Available"
            case .touchID:
                biometricStatus = "Touch ID Available"
            case .opticID:
                biometricStatus = "Optic ID Available"
            default:
                biometricStatus = "Biometric Available"
            }
        } else {
            biometricStatus = "Not Available"
        }
    }
    
    private func checkStorageStatus() {
        // Check if Supabase Storage bucket is configured
        storageStatus = Config.supabaseStorageBucket.isEmpty ? "Not Available" : "Available"
    }
    
    private func validateProductionReadiness() {
        issues.removeAll()
        
        // Check for demo data
        if hasDemoData {
            issues.append("Demo data detected")
        }
        
        // Check network status
        if networkStatus == "Disconnected" {
            issues.append("Network connectivity issues")
        }
        
        // Check backend status
        if firebaseStatus.contains("Not Configured") {
            issues.append("Supabase not configured")
        }
        
        // Check biometric status
        if biometricStatus == "Not Available" {
            issues.append("Biometric authentication not available")
        }
        
        // Check storage status
        if storageStatus != "Available" {
            issues.append("Storage not available")
        }
        
        // Check for production mode
        if !UserDefaults.standard.bool(forKey: "isProductionMode") {
            issues.append("Not in production mode")
        }
        
        // Determine if app is production ready
        isProductionReady = issues.isEmpty
    }
    
    func getStatusColor() -> Color {
        if isProductionReady {
            return .green
        } else if issues.count <= 2 {
            return .orange
        } else {
            return .red
        }
    }
    
    func getStatusText() -> String {
        if isProductionReady {
            return "Production Ready"
        } else if issues.count <= 2 {
            return "Minor Issues"
        } else {
            return "Major Issues"
        }
    }
}

// MARK: - App Status View
struct AppStatusView: View {
    @StateObject private var statusChecker = AppStatusChecker.shared
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Status Header
            HStack {
                Circle()
                    .fill(statusChecker.getStatusColor())
                    .frame(width: 20, height: 20)
                
                Text(statusChecker.getStatusText())
                    .font(.headline)
                    .foregroundColor(statusChecker.getStatusColor())
                
                Spacer()
                
                Button("Refresh") {
                    statusChecker.checkAppStatus()
                }
                .font(.caption)
            }
            
            // Status Details
            if showDetails {
                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(title: "Network", status: statusChecker.networkStatus)
                    StatusRow(title: "Backend", status: statusChecker.firebaseStatus)
                    StatusRow(title: "Biometric", status: statusChecker.biometricStatus)
                    StatusRow(title: "Storage", status: statusChecker.storageStatus)
                    StatusRow(title: "Demo Data", status: statusChecker.hasDemoData ? "Present" : "Clean")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Issues List
            if !statusChecker.issues.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Issues:")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    ForEach(statusChecker.issues, id: \.self) { issue in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(issue)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Toggle Details Button
            Button(showDetails ? "Hide Details" : "Show Details") {
                withAnimation {
                    showDetails.toggle()
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}

struct StatusRow: View {
    let title: String
    let status: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "connected", "configured", "available", "clean":
            return .green
        case "disconnected", "not configured", "not available", "present":
            return .red
        default:
            return .orange
        }
    }
}

struct AppStatusView_Previews: PreviewProvider {
    static var previews: some View {
        AppStatusView()
    }
}
