import SwiftUI

enum LegalURLs {
    static let privacy = URL(string: "https://lettalkapp.com/privacy")!
    static let terms = URL(string: "https://lettalkapp.com/terms")!
    static let support = URL(string: "https://lettalkapp.com/support")!
    /// Support email shown in Settings › About. The mailbox (or a forward) must exist on lettalkapp.com.
    static let supportEmail: String? = "support@lettalkapp.com"
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
