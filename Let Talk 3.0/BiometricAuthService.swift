import Foundation
import LocalAuthentication

// MARK: - Biometric Authentication Service
class BiometricAuthService: ObservableObject {
    static let shared = BiometricAuthService()
    
    @Published var isBiometricAvailable = false
    @Published var biometricType: LABiometryType = .none
    
    private init() {
        checkBiometricAvailability()
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricAvailable = true
            biometricType = context.biometryType
        } else {
            isBiometricAvailable = false
            biometricType = .none
        }
    }
    
    func authenticateWithBiometrics() async throws {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthError.biometricNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, 
                                 localizedReason: "Authenticate to access your account") { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? AuthError.biometricFailed)
                }
            }
        }
    }
    
    var biometricTypeString: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Biometric"
        }
    }
}
