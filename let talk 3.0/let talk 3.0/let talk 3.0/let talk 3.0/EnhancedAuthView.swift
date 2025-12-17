import SwiftUI

struct EnhancedAuthView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var biometricAuth = BiometricAuthService.shared
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showPhoneVerification = false
    @State private var showMainApp = false
    @State private var showBiometricAlert = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.6),
                    Color.pink.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer(minLength: 50)
                    
                    // App Logo
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    
                    // Title
                    Text("Let Talk")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Subtitle
                    Text(isLoginMode ? "Welcome back!" : "Create your account")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    // Form
                    VStack(spacing: 20) {
                        if !isLoginMode {
                            // Name field (only for registration)
                            CustomTextField(
                                text: $name,
                                placeholder: "Full Name",
                                icon: "person.fill"
                            )
                        }
                        
                        // Email field
                        CustomTextField(
                            text: $email,
                            placeholder: "Email Address",
                            icon: "envelope.fill",
                            keyboardType: .emailAddress
                        )
                        
                        // Password field
                        CustomTextField(
                            text: $password,
                            placeholder: "Password",
                            icon: "lock.fill",
                            isSecure: true
                        )
                        
                        if !isLoginMode {
                            // Confirm password field (only for registration)
                            CustomTextField(
                                text: $confirmPassword,
                                placeholder: "Confirm Password",
                                icon: "lock.fill",
                                isSecure: true
                            )
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Error message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                            .padding(.horizontal, 30)
                    }
                    
                    // Network status
                    if !networkMonitor.isConnected {
                        HStack {
                            Image(systemName: "wifi.slash")
                            Text("No internet connection")
                        }
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                        .padding(.horizontal, 30)
                    }
                    
                    // Action buttons
                    VStack(spacing: 15) {
                        // Main action button
                        Button(action: handleAuthAction) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(isLoginMode ? "Sign In" : "Create Account")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.white.opacity(0.2))
                            )
                            .foregroundColor(.white)
                        }
                        .disabled(isLoading || !networkMonitor.isConnected)
                        
                        // Biometric authentication (only for login)
                        if isLoginMode && biometricAuth.isBiometricAvailable {
                            Button(action: authenticateWithBiometrics) {
                                HStack {
                                    Image(systemName: biometricAuth.biometricType == .faceID ? "faceid" : "touchid")
                                    Text("Sign in with \(biometricAuth.biometricTypeString)")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(Color.white.opacity(0.1))
                                )
                                .foregroundColor(.white)
                            }
                            .disabled(isLoading)
                        }
                        
                        // Toggle mode button
                        Button(action: toggleMode) {
                            Text(isLoginMode ? "Don't have an account? Sign Up" : "Already have an account? Sign In")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .fullScreenCover(isPresented: $showPhoneVerification) {
            PhoneVerificationView(
                isPresented: $showPhoneVerification,
                isLoggedIn: $showMainApp
            )
            .environmentObject(authManager)
        }
        .fullScreenCover(isPresented: $showMainApp) {
            MainTabView()
        }
        .alert("Biometric Authentication", isPresented: $showBiometricAlert) {
            Button("OK") { }
        } message: {
            Text("Biometric authentication is not available on this device.")
        }
    }
    
    private func handleAuthAction() {
        guard networkMonitor.isConnected else {
            errorMessage = "Please check your internet connection"
            return
        }
        
        guard validateInputs() else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                if isLoginMode {
                    try await authManager.signIn(email: email, password: password)
                } else {
                    try await authManager.signUp(email: email, password: password, name: name)
                }
                
                await MainActor.run {
                    isLoading = false
                    if isLoginMode {
                        // For login, check if user needs phone verification
                        if authManager.needsPhoneVerification {
                            showPhoneVerification = true
                        } else {
                            showMainApp = true
                        }
                    } else {
                        // For sign up, always show phone verification
                        showPhoneVerification = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func authenticateWithBiometrics() {
        Task {
            do {
                try await biometricAuth.authenticateWithBiometrics()
                await MainActor.run {
                    showMainApp = true
                }
            } catch {
                await MainActor.run {
                    showBiometricAlert = true
                }
            }
        }
    }
    
    private func toggleMode() {
        withAnimation {
            isLoginMode.toggle()
            errorMessage = ""
        }
    }
    
    private func validateInputs() -> Bool {
        if email.isEmpty || password.isEmpty {
            errorMessage = "Please fill in all required fields"
            return false
        }
        
        if !isLoginMode {
            if name.isEmpty {
                errorMessage = "Please enter your name"
                return false
            }
            
            if password != confirmPassword {
                errorMessage = "Passwords do not match"
                return false
            }
            
            if password.count < 6 {
                errorMessage = "Password must be at least 6 characters"
                return false
            }
        }
        
        if !email.contains("@") {
            errorMessage = "Please enter a valid email address"
            return false
        }
        
        return true
    }
}

struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .keyboardType(keyboardType)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .keyboardType(keyboardType)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct EnhancedAuthView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedAuthView()
    }
}
