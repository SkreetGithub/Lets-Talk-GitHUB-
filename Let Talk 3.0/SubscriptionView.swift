import SwiftUI
import StoreKit

// MARK: - StoreKit 2 manager

enum LetTalkProduct {
    static let monthly = "com.upappllc.lettalk.premium.monthly"
    static let yearly = "com.upappllc.lettalk.premium.yearly"
    static let all = [monthly, yearly]
}

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isSubscribed = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
        Task { await loadProducts(); await refreshEntitlements() }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: LetTalkProduct.all)
            products = fetched.sorted { $0.price < $1.price }
            if fetched.isEmpty {
                errorMessage = "Subscriptions are not available right now."
            }
        } catch {
            errorMessage = "Couldn't load subscriptions. Please try again."
        }
    }

    func purchase(_ product: Product) async {
        errorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                } else {
                    errorMessage = "Purchase could not be verified."
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed. You were not charged."
        }
    }

    func restore() async {
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isSubscribed { errorMessage = "No active subscription was found to restore." }
        } catch {
            errorMessage = "Couldn't restore purchases. Please try again."
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               LetTalkProduct.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
    }
}

// MARK: - Paywall

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var store = StoreManager.shared
    @State private var purchasing = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    features

                    if store.isSubscribed {
                        Label("You're subscribed to Let Talk Premium", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                    } else if store.isLoading && store.products.isEmpty {
                        ProgressView()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.products, id: \.id) { product in
                                Button {
                                    Task {
                                        purchasing = true
                                        await store.purchase(product)
                                        purchasing = false
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(product.displayName).font(.headline)
                                            Text(periodText(for: product)).font(.caption)
                                        }
                                        Spacer()
                                        Text(product.displayPrice).font(.headline)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(purchasing)
                            }
                        }
                    }

                    if let message = store.errorMessage {
                        Text(message).font(.footnote).foregroundColor(.red).multilineTextAlignment(.center)
                    }

                    Button("Restore Purchases") { Task { await store.restore() } }
                        .font(.subheadline)

                    terms
                }
                .padding()
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func periodText(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        switch period.unit {
        case .month: return "Billed monthly. Auto-renews until cancelled."
        case .year: return "Billed yearly. Auto-renews until cancelled."
        case .week: return "Billed weekly. Auto-renews until cancelled."
        case .day: return "Billed daily. Auto-renews until cancelled."
        @unknown default: return ""
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundColor(.yellow)
            Text("Let Talk Premium").font(.title2.bold())
            Text("Talk to anyone in any language.").font(.subheadline).foregroundColor(.secondary)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureRow(icon: "infinity", title: "Unlimited Translations", description: "Translate without limits")
            FeatureRow(icon: "mic.fill", title: "Live Call Translation", description: "Real-time subtitles and voice")
            FeatureRow(icon: "camera.fill", title: "Camera Translation", description: "Translate text from photos")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var terms: some View {
        VStack(spacing: 6) {
            Text("Payment is charged to your Apple ID at confirmation. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings > Apple ID > Subscriptions.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            LegalLinksView()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
