import SwiftUI

// The old sign-up form (`AuthView`, blue gradient, "Let's Talk") was removed: there is now ONE
// sign-in / sign-up screen, `EnhancedAuthView`, which collects name, phone, email and password.
// The original is in git history and in "Let Talk 3.0_BACKUP.tar.gz".
//
// This file keeps the password-reset sheet, opened from "Forgot password?" on the sign-in screen.

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var didSend = false
    @State private var isLoading = false

    private static let actionPink = Color(red: 0.80, green: 0.08, blue: 0.40)

    var body: some View {
        NavigationStack {
            ZStack {
                // Same gradient as the sign-in screen. The shared text field draws white text,
                // which was invisible on the old plain white background.
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6), Color.pink.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: DS.spacingL) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 56))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.white)
                        .accessibilityHidden(true)

                    VStack(spacing: DS.spacingS) {
                        Text("Reset Password")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        Text("Enter your email and we'll send you a link to reset your password.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }

                    CustomTextField(text: $email, placeholder: "Email Address", icon: "envelope.fill",
                                    keyboardType: .emailAddress)
                        .textContentType(.emailAddress)

                    Button(action: resetPassword) {
                        ZStack {
                            Text("Send Reset Link")
                                .font(.headline)
                                .foregroundColor(Self.actionPink)
                                .opacity(isLoading ? 0 : 1)
                            ProgressView()
                                .tint(Self.actionPink)
                                .opacity(isLoading ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: DS.primaryButtonHeight)
                        .background(RoundedRectangle(cornerRadius: 25).fill(Color.white.opacity(isValid ? 1 : 0.6)))
                        .contentShape(RoundedRectangle(cornerRadius: 25))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(!isValid || isLoading)

                    Spacer()
                }
                .padding(.horizontal, DS.spacingL)
                .padding(.top, DS.spacingXL)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.white)
                }
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if didSend { dismiss() }
                }
            }
        }
    }

    private var isValid: Bool {
        email.contains("@") && email.contains(".")
    }

    private func resetPassword() {
        isLoading = true
        Task {
            do {
                try await AuthManager.shared.resetPassword(email: email.trimmingCharacters(in: .whitespaces))
                await MainActor.run {
                    didSend = true
                    alertMessage = "Password reset link has been sent to your email."
                    showAlert = true
                    isLoading = false
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    didSend = false
                    alertMessage = error.localizedDescription
                    showAlert = true
                    isLoading = false
                    Haptics.failure()
                }
            }
        }
    }
}
