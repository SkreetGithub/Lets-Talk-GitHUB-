import SwiftUI

/// The ONE sign-in / sign-up screen. Sign-up asks for name, phone, email and password
/// (the phone number is needed for calling). Onboarding opens it in sign-up mode.
///
/// Navigation after auth is owned by the app root (`Let_Talk_3_0App` swaps to MainTabView
/// when `isAuthenticated` turns true), so this screen never presents MainTabView itself.
struct EnhancedAuthView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared

    @State private var isLoginMode: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var phone = ""
    @State private var gender: VoiceGender?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var infoMessage = ""
    @State private var showPhoneVerification = false
    @State private var showForgotPassword = false

    /// Darker pink (about 5.4:1 on white) so the button label passes WCAG AA.
    private static let actionPink = Color(red: 0.80, green: 0.08, blue: 0.40)

    init(startInSignUp: Bool = false) {
        _isLoginMode = State(initialValue: !startInSignUp)
    }

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
                VStack(spacing: DS.spacingL) {
                    Spacer(minLength: DS.spacingXL)

                    // App Logo
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 80))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.white)
                        .accessibilityHidden(true)

                    VStack(spacing: DS.spacingS) {
                        Text("Let Talk")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(isLoginMode ? "Welcome back!" : "Create your account")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .contentTransition(.opacity)
                    }

                    // Form
                    VStack(spacing: DS.spacingM) {
                        if !isLoginMode {
                            CustomTextField(text: $name, placeholder: "Full Name", icon: "person.fill")
                                .textContentType(.name)
                                .transition(.move(edge: .top).combined(with: .opacity))

                            CustomTextField(text: $phone, placeholder: "Phone Number", icon: "phone.fill",
                                            keyboardType: .phonePad)
                                .textContentType(.telephoneNumber)
                                .transition(.move(edge: .top).combined(with: .opacity))

                            voicePicker
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        CustomTextField(text: $email, placeholder: "Email Address", icon: "envelope.fill",
                                        keyboardType: .emailAddress)
                            .textContentType(.emailAddress)

                        CustomTextField(text: $password, placeholder: "Password", icon: "lock.fill", isSecure: true)
                            .textContentType(isLoginMode ? .password : .newPassword)

                        if !isLoginMode {
                            CustomTextField(text: $confirmPassword, placeholder: "Confirm Password",
                                            icon: "lock.fill", isSecure: true)
                                .textContentType(.newPassword)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                    // Messages (white text on a tinted pill: red text on the pink gradient was unreadable)
                    if !errorMessage.isEmpty {
                        messagePill(errorMessage, icon: "exclamationmark.circle.fill", tint: .red)
                    }
                    if !infoMessage.isEmpty {
                        messagePill(infoMessage, icon: "envelope.badge.fill", tint: .green)
                    }
                    if !networkMonitor.isConnected {
                        messagePill("No internet connection", icon: "wifi.slash", tint: .red)
                    }

                    // Action buttons
                    VStack(spacing: DS.spacingM) {
                        Button(action: handleAuthAction) {
                            ZStack {
                                Text(isLoginMode ? "Sign In" : "Create Account")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Self.actionPink)
                                    .opacity(isLoading ? 0 : 1)
                                ProgressView()
                                    .tint(Self.actionPink)
                                    .opacity(isLoading ? 1 : 0)
                            }
                            .animation(.easeInOut(duration: 0.2), value: isLoading)
                            .frame(maxWidth: .infinity)
                            .frame(height: DS.primaryButtonHeight)
                            .background(RoundedRectangle(cornerRadius: 25).fill(Color.white))
                            .contentShape(RoundedRectangle(cornerRadius: 25))
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(isLoading || !networkMonitor.isConnected)
                        .opacity(isLoading || !networkMonitor.isConnected ? 0.7 : 1)

                        AppleSignInButton(
                            label: isLoginMode ? .signIn : .signUp,
                            onSuccess: handleAppleSignInSuccess,
                            onError: { message in
                                errorMessage = message
                                Haptics.failure()
                            }
                        )
                        .disabled(isLoading || !networkMonitor.isConnected)

                        Button(action: signInWithGoogle) {
                            Text(isLoginMode ? "Sign in with Google" : "Sign up with Google")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                                .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(isLoading || !networkMonitor.isConnected)
                        .accessibilityLabel(isLoginMode ? "Sign in with Google" : "Sign up with Google")

                        if isLoginMode {
                            Button("Forgot password?") { showForgotPassword = true }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .frame(minHeight: DS.minTapTarget)
                        }

                        Button(action: toggleMode) {
                            Text(isLoginMode ? "Don't have an account? Sign Up" : "Already have an account? Sign In")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(minHeight: DS.minTapTarget)
                        }

                        VStack(spacing: DS.spacingXS) {
                            Text("By continuing you agree to our")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.8))
                            LegalLinksView()
                                .tint(.white)
                        }
                    }

                    Spacer(minLength: DS.spacingXL)
                }
                .padding(.horizontal, DS.spacingL)   // one inset for fields, messages and buttons
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .fullScreenCover(isPresented: $showPhoneVerification) {
            PhoneVerificationView(isPresented: $showPhoneVerification, isLoggedIn: .constant(false))
                .environmentObject(authManager)
        }
        // A signed-in user without a phone number (e.g. Sign in with Apple) picks one next.
        .onAppear { showPhoneVerification = authManager.needsPhoneVerification }
        .onChange(of: authManager.needsPhoneVerification) { _, needsPhone in
            showPhoneVerification = needsPhone
        }
    }

    /// Male / Female choice for the voice other people hear when this user's speech is
    /// translated. Required at sign-up; changeable later in Settings → Voice Settings.
    private var voicePicker: some View {
        VStack(alignment: .leading, spacing: DS.spacingS) {
            Text("Your translated voice")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.leading, DS.spacingS)

            HStack(spacing: DS.spacingS) {
                ForEach(VoiceGender.allCases) { option in
                    let selected = gender == option
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { gender = option }
                        Haptics.tap()
                    } label: {
                        HStack(spacing: DS.spacingXS) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            Text(option.title)
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(selected ? Self.actionPink : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 25)
                            .fill(selected ? Color.white : Color.white.opacity(0.1)))
                        .overlay(RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(selected ? 0 : 0.2), lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 25))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(option.title) voice")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }

            Text("People you call hear your translated speech in this voice. You can change it anytime in Settings.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DS.spacingS)
        }
    }

    private func messagePill(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, DS.spacingM)
            .padding(.vertical, DS.spacingS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DS.cornerRadiusS).fill(tint.opacity(0.75)))
            .transition(.opacity)
    }

    private func handleAuthAction() {
        guard networkMonitor.isConnected else {
            errorMessage = "Please check your internet connection."
            Haptics.failure()
            return
        }
        guard validateInputs() else {
            Haptics.failure()
            return
        }

        isLoading = true
        errorMessage = ""
        infoMessage = ""

        Task {
            do {
                if isLoginMode {
                    try await authManager.signIn(email: email, password: password)
                    await MainActor.run { Haptics.success() }
                } else {
                    let signedIn = try await authManager.signUp(
                        email: email.trimmingCharacters(in: .whitespaces),
                        password: password,
                        name: name.trimmingCharacters(in: .whitespaces),
                        phone: normalizedPhone,
                        gender: gender
                    )
                    await MainActor.run {
                        Haptics.success()
                        if !signedIn {
                            // Email confirmation is on in Supabase.
                            infoMessage = "Check your email to confirm your account, then sign in."
                            withAnimation(DS.screenTransition) { isLoginMode = true }
                        }
                    }
                }
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let nsError = error as NSError
                    errorMessage = nsError.domain == NSURLErrorDomain
                        ? "Sign up failed: Please check your internet connection."
                        : error.localizedDescription
                    Haptics.failure()
                }
            }
        }
    }

    private func handleAppleSignInSuccess() {
        Haptics.success()
        showPhoneVerification = authManager.needsPhoneVerification
    }

    /// Same onboarding as Apple: a new Google user picks a phone number next.
    private func signInWithGoogle() {
        errorMessage = ""
        Task {
            do {
                guard try await authManager.signInWithGoogle() else { return }   // closed the sheet
                handleAppleSignInSuccess()
            } catch {
                errorMessage = "Google sign-in didn't complete. Please try again."
                Haptics.failure()
            }
        }
    }

    private func toggleMode() {
        withAnimation(DS.screenTransition) {
            isLoginMode.toggle()
            errorMessage = ""
            infoMessage = ""
        }
    }

    /// Digits only, keeping a leading "+" for international numbers.
    private var normalizedPhone: String {
        let trimmed = phone.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.filter(\.isNumber)
        return trimmed.hasPrefix("+") ? "+" + digits : digits
    }

    private func validateInputs() -> Bool {
        if email.isEmpty || password.isEmpty {
            errorMessage = "Please fill in all required fields."
            return false
        }
        if !email.contains("@") {
            errorMessage = "Please enter a valid email address."
            return false
        }
        if !isLoginMode {
            if name.trimmingCharacters(in: .whitespaces).isEmpty {
                errorMessage = "Please enter your name."
                return false
            }
            let digitCount = normalizedPhone.filter(\.isNumber).count
            if digitCount < 10 || digitCount > 15 {
                errorMessage = "Please enter a valid phone number."
                return false
            }
            if gender == nil {
                errorMessage = "Please choose your translated voice: Male or Female."
                return false
            }
            if password.count < 6 {
                errorMessage = "Password must be at least 6 characters."
                return false
            }
            if password != confirmPassword {
                errorMessage = "Passwords don't match."
                return false
            }
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
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.7)))
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .keyboardType(keyboardType)
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.7)))
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : nil)
                    .autocorrectionDisabled(keyboardType == .emailAddress)
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
