import SwiftUI

enum LegalURLs {
    static let privacy = URL(string: "https://lettalk.app/privacy")!
    static let terms = URL(string: "https://lettalk.app/terms")!
    static let support = URL(string: "https://lettalk.app/support")!
    /// Support email shown in Settings › About. Set it once the address exists (e.g. "support@lettalk.app").
    static let supportEmail: String? = "support@lettalk.app"
}

struct LegalLinksView: View {
    var body: some View {
        HStack(spacing: 6) {
            Link("Privacy Policy", destination: LegalURLs.privacy)
            Text("·").foregroundColor(.secondary)
            Link("Terms of Service", destination: LegalURLs.terms)
        }
        .font(.footnote)
    }
}
