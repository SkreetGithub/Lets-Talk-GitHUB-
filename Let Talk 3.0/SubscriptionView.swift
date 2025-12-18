import SwiftUI
import PassKit

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SubscriptionViewModel()
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var showPaymentSheet = false
    @State private var showApplePay = false
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    headerView
                    
                    // Features List
                    featuresView
                    
                    // Pricing Plans
                    pricingPlansView
                    
                    // Payment Buttons
                    paymentButtonsView
                    
                    // Terms and Privacy
                    termsView
                }
                .padding()
            }
            .navigationTitle("Premium Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Close") { dismiss() })
        }
        .sheet(isPresented: $showPaymentSheet) {
            PaymentSheetView(plan: selectedPlan, onSuccess: {
                viewModel.handlePaymentSuccess()
                dismiss()
            })
        }
        .sheet(isPresented: $showApplePay) {
            ApplePayView(plan: selectedPlan, onSuccess: {
                viewModel.handlePaymentSuccess()
                dismiss()
            })
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Unlock Premium Features")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Get unlimited access to all premium features")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var featuresView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium Features")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 12) {
                FeatureRow(icon: "infinity", title: "Unlimited Translations", description: "Translate without limits")
                FeatureRow(icon: "camera.fill", title: "Camera Translation", description: "Translate text from photos")
                FeatureRow(icon: "mic.fill", title: "Voice Translation", description: "Real-time voice translation")
                FeatureRow(icon: "phone.fill", title: "Premium Calling", description: "HD audio and video calls")
                FeatureRow(icon: "message.fill", title: "Advanced Messaging", description: "Rich media and effects")
                FeatureRow(icon: "cloud.fill", title: "Cloud Sync", description: "Sync across all devices")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var pricingPlansView: some View {
        VStack(spacing: 16) {
            Text("Choose Your Plan")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                // Monthly Plan
                PricingCard(
                    plan: .monthly,
                    isSelected: selectedPlan == .monthly,
                    onTap: { selectedPlan = .monthly }
                )
                
                // Yearly Plan
                PricingCard(
                    plan: .yearly,
                    isSelected: selectedPlan == .yearly,
                    onTap: { selectedPlan = .yearly }
                )
            }
        }
    }
    
    private var paymentButtonsView: some View {
        VStack(spacing: 16) {
            // Apple Pay Button
            if PKPaymentAuthorizationViewController.canMakePayments() {
                Button(action: { showApplePay = true }) {
                    HStack {
                        Image(systemName: "applelogo")
                            .font(.title2)
                        Text("Pay with Apple Pay")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(12)
                }
            }
            
            // Stripe Payment Button
            Button(action: { showPaymentSheet = true }) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.title2)
                    Text("Pay with Card")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(isProcessing)
            
            if isProcessing {
                ProgressView("Processing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var termsView: some View {
        VStack(spacing: 8) {
            Text("By subscribing, you agree to our")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Button("Terms of Service") {
                    // Open terms
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Text("and")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Privacy Policy") {
                    // Open privacy policy
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Pricing Card
struct PricingCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text(plan.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(plan.price)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            if plan == .yearly {
                Text("Save 20%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text(plan.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Subscription Plan
enum SubscriptionPlan: CaseIterable {
    case monthly
    case yearly
    
    var title: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
    
    var price: String {
        switch self {
        case .monthly: return "$9.99/month"
        case .yearly: return "$79.99/year"
        }
    }
    
    var description: String {
        switch self {
        case .monthly: return "Billed monthly"
        case .yearly: return "Billed annually"
        }
    }
    
    var stripePriceId: String {
        switch self {
        case .monthly: return "price_monthly_premium"
        case .yearly: return "price_yearly_premium"
        }
    }
}

// MARK: - Payment Sheet View
struct PaymentSheetView: View {
    let plan: SubscriptionPlan
    let onSuccess: () -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PaymentViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Complete Payment")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Plan: \(plan.title)")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("Amount: \(plan.price)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Stripe Payment Form would go here
                // For now, we'll show a placeholder
                VStack(spacing: 16) {
                    TextField("Card Number", text: $viewModel.cardNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        TextField("MM/YY", text: $viewModel.expiryDate)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("CVC", text: $viewModel.cvc)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    TextField("Cardholder Name", text: $viewModel.cardholderName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                
                Button("Complete Payment") {
                    viewModel.processPayment(plan: plan) { success in
                        if success {
                            onSuccess()
                        }
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .disabled(viewModel.isProcessing)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

// MARK: - Apple Pay View
struct ApplePayView: View {
    let plan: SubscriptionPlan
    let onSuccess: () -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ApplePayViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Apple Pay")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Plan: \(plan.title)")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("Amount: \(plan.price)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Pay with Apple Pay") {
                    viewModel.processApplePayPayment(plan: plan) { success in
                        if success {
                            onSuccess()
                        }
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(12)
                .disabled(viewModel.isProcessing)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Apple Pay")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

// MARK: - View Models
class SubscriptionViewModel: ObservableObject {
    @Published var isSubscribed = false
    @Published var error: Error?
    
    func handlePaymentSuccess() {
        isSubscribed = true
        // Update user subscription status in Firebase
    }
}

class PaymentViewModel: ObservableObject {
    @Published var cardNumber = ""
    @Published var expiryDate = ""
    @Published var cvc = ""
    @Published var cardholderName = ""
    @Published var isProcessing = false
    
    func processPayment(plan: SubscriptionPlan, completion: @escaping (Bool) -> Void) {
        isProcessing = true
        
        // Simulate payment processing
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            self.isProcessing = false
            completion(true) // Simulate success
        }
    }
}

class ApplePayViewModel: ObservableObject {
    @Published var isProcessing = false
    
    func processApplePayPayment(plan: SubscriptionPlan, completion: @escaping (Bool) -> Void) {
        isProcessing = true
        
        // Simulate Apple Pay processing
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            self.isProcessing = false
            completion(true) // Simulate success
        }
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
    }
}
