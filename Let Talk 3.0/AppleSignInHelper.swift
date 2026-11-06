import SwiftUI
import AuthenticationServices
import CryptoKit

/// Nonce helpers for Sign in with Apple. Apple receives the SHA-256 of the nonce,
/// Supabase receives the raw nonce and checks the two match.
enum AppleSignInNonce {
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess { fatalError("Unable to generate nonce (OSStatus \(status))") }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// "Sign in with Apple" button wired to `AuthManager.signInWithApple`.
struct AppleSignInButton: View {
    let label: SignInWithAppleButton.Label
    let onSuccess: () -> Void
    let onError: (String) -> Void

    @State private var rawNonce = ""

    var body: some View {
        SignInWithAppleButton(label) { request in
            rawNonce = AppleSignInNonce.randomNonceString()
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(rawNonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    onError("Apple sign-in returned an unexpected credential.")
                    return
                }
                let nonce = rawNonce
                Task {
                    do {
                        try await AuthManager.shared.signInWithApple(credential: credential, rawNonce: nonce)
                        await MainActor.run { onSuccess() }
                    } catch {
                        await MainActor.run { onError(error.localizedDescription) }
                    }
                }
            case .failure(let error):
                if (error as? ASAuthorizationError)?.code == .canceled { return }
                onError(error.localizedDescription)
            }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 50)
        .cornerRadius(12)
    }
}
