import SwiftUI

/// One-time consent before any text/speech is sent to third-party translation providers.
final class AIConsent: ObservableObject {
    static let shared = AIConsent()
    private let key = "ai_translation_consent_v1"

    @Published var hasConsented: Bool
    @Published var needsPrompt = false

    private init() {
        hasConsented = UserDefaults.standard.bool(forKey: key)
    }

    func grant() {
        UserDefaults.standard.set(true, forKey: key)
        hasConsented = true
        needsPrompt = false
    }

    func revoke() {
        UserDefaults.standard.set(false, forKey: key)
        hasConsented = false
    }

    /// Call before sending anything to a translation provider. Returns false (and asks the user) if not yet consented.
    @discardableResult
    func requireConsent() -> Bool {
        if hasConsented { return true }
        DispatchQueue.main.async { self.needsPrompt = true }
        return false
    }
}

struct AIConsentView: View {
    @ObservedObject var consent = AIConsent.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            Text("Before we translate")
                .font(.title2.bold())
            Text("Your speech is converted to text on your iPhone. To translate your calls and messages, Let Talk sends the recognized text (not audio) to Google Translate and OpenAI. We do not sell this data, and we do not use it for advertising.")
                .font(.body)
                .multilineTextAlignment(.center)
            LegalLinksView()
            Button {
                consent.grant()
            } label: {
                Text("I Agree")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            Button("Cancel") {
                consent.needsPrompt = false
            }
            .foregroundColor(.secondary)
        }
        .padding(24)
    }
}
