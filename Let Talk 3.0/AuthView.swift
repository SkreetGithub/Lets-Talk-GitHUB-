import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var phone = ""
    @State private var showForgotPassword = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showPhoneVerification = false
    
    private var isValidForm: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !name.isEmpty && !phone.isEmpty &&
                   password == confirmPassword && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(gradient: Gradient(colors: [.blue, .purple]),
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                // Content
                ScrollView {
                    VStack(spacing: 25) {
                        // Logo or App Name
                        Text("Let's Talk")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 50)
                        
                        // Form Fields
                        VStack(spacing: 20) {
                            if isSignUp {
                                // Name Field
                                CustomTextField(text: $name,
                                             placeholder: "Full Name",
                                             icon: "person.fill")
                                
                                // Phone Field
                                CustomTextField(text: $phone,
                                             placeholder: "Phone Number",
                                             icon: "phone.fill",
                                             keyboardType: .phonePad)
                            }
                            
                            // Email Field
                            CustomTextField(text: $email,
                                         placeholder: "Email",
                                         icon: "envelope.fill",
                                         keyboardType: .emailAddress)
                            
                            // Password Field
                            CustomSecureField(text: $password,
                                           placeholder: "Password",
                                           icon: "lock.fill")
                            
                            if isSignUp {
                                // Confirm Password Field
                                CustomSecureField(text: $confirmPassword,
                                               placeholder: "Confirm Password",
                                               icon: "lock.fill")
                            }
                        }
                        .padding(.horizontal)
                        
                        // Action Button
                        Button(action: handleAuth) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(!isValidForm || isLoading)
                        .padding()
                        .background(isValidForm ? Color.blue : Color.gray)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        // Toggle Sign In/Up
                        Button(action: { isSignUp.toggle() }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .foregroundColor(.white)
                        }
                        
                        if !isSignUp {
                            // Forgot Password
                            Button(action: { showForgotPassword = true }) {
                                Text("Forgot Password?")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding()
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
            .sheet(isPresented: $showPhoneVerification) {
                PhoneVerificationView(
                    isPresented: $showPhoneVerification,
                    isLoggedIn: .constant(false)
                )
                .environmentObject(authManager)
            }
        }
    }
    
    private func handleAuth() {
        isLoading = true
        
        Task {
            do {
                if isSignUp {
                    try await authManager.signUp(email: email,
                                               password: password,
                                               name: name)
                } else {
                    try await authManager.signIn(email: email,
                                               password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

// Note: CustomTextField is defined in EnhancedAuthView.swift

struct CustomSecureField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    @State private var isSecure = true
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
            
            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 3)
    }
}

struct ForgotPasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Reset Password")
                    .font(.title)
                    .padding()
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                CustomTextField(text: $email,
                             placeholder: "Email",
                             icon: "envelope.fill",
                             keyboardType: .emailAddress)
                    .padding()
                
                Button(action: resetPassword) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Reset Link")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(email.isEmpty || isLoading)
                .padding()
                .background(email.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .padding()
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if alertMessage.contains("sent") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func resetPassword() {
        isLoading = true
        
        Task {
            do {
                try await AuthManager.shared.resetPassword(email: email)
                alertMessage = "Password reset link has been sent to your email."
                showAlert = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isLoading = false
        }
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthManager.shared)
    }
}
