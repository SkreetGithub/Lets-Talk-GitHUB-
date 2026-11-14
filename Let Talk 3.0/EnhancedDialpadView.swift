import SwiftUI
import WebRTC

/// The dial pad (Calls tab › green phone button). Styled like the iPhone's own keypad:
/// big glass keys on a dark, slowly moving brand-color background.
struct EnhancedDialpadView: View {
    @Binding var isPresented: Bool
    @State private var phoneNumber = ""
    @State private var showCallOptions = false
    @State private var isShaking = false
    @State private var showInvalidNumberAlert = false
    @State private var searchText = ""
    @State private var showContacts = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let keys: [[(String, String)]] = [
        [("1", ""), ("2", "ABC"), ("3", "DEF")],
        [("4", "GHI"), ("5", "JKL"), ("6", "MNO")],
        [("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ")],
        [("*", ""), ("0", "+"), ("#", "")]
    ]

    var body: some View {
        ZStack {
            // The call screen's moving glows, turned well down so the numbers stay the focus.
            // Only the background runs under the Dynamic Island and home indicator.
            CallAuraBackground(base: Brand.ink, isLive: false, intensity: 0.45)
                .ignoresSafeArea()
            
            // Everything else stays inside the safe area, and every size is worked out from
            // the space that is actually there, so nothing is cut off on any iPhone.
            GeometryReader { geometry in
                let metrics = DialpadMetrics(size: geometry.size)
                
                VStack(spacing: 0) {
                    // Close (top left)
                    HStack {
                        closeButton
                        Spacer()
                    }
                    .padding(.leading, DS.spacingM)
                    .padding(.top, metrics.topPadding)
                    
                    phoneNumberDisplay
                        .padding(.top, metrics.gap)
                    
                    // Your saved contacts appear once you start typing (tap one to fill in the number).
                    if metrics.showsContacts {
                        contactsSearchView
                            .frame(height: DialpadMetrics.contactsHeight)
                            .opacity(phoneNumber.isEmpty ? 0 : 1)
                            .animation(.easeInOut(duration: 0.2), value: phoneNumber.isEmpty)
                    }
                    
                    Spacer(minLength: metrics.gap)
                    
                    dialpadGrid(metrics)
                        .modifier(ShakeEffect(shakes: isShaking ? 2 : 0))
                    
                    callButton(size: metrics.key)
                        .padding(.top, metrics.callGap)
                        .padding(.bottom, metrics.bottomPadding)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .environment(\.colorScheme, .dark)
        .presentationDragIndicator(.visible)
        // Modern replacement for ActionSheet (deprecated), whose buttons were dropping taps.
        .confirmationDialog("Call Options", isPresented: $showCallOptions, titleVisibility: .visible) {
            Button("Audio Call") { makeCall(isVideo: false) }
            Button("Video Call") { makeCall(isVideo: true) }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Invalid Number", isPresented: $showInvalidNumberAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter a valid 10-digit phone number")
        }
    }

    private var closeButton: some View {
        Button(action: dismissDialpad) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: DS.minTapTarget, height: DS.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Close dial pad")
    }
    
    // MARK: - Number display

    private var phoneNumberDisplay: some View {
        HStack(spacing: DS.spacingS) {
            // Invisible twin of the delete button keeps the number exactly centered.
            Color.clear.frame(width: DS.minTapTarget, height: DS.minTapTarget)

            Text(phoneNumber.isEmpty ? " " : formatPhoneNumber(phoneNumber))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.35), radius: 10)          // soft glow
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(reduceMotion ? .identity : .numericText())  // digits roll in and out
                .frame(maxWidth: .infinity)
                .overlay {
                    if phoneNumber.isEmpty {
                        Text("Enter a number")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .transition(.opacity)
                    }
                }
                .accessibilityLabel(phoneNumber.isEmpty ? "No number entered" : "Number, \(phoneNumber)")

            Button(action: deleteLastDigit) {
                Image(systemName: "delete.left")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: DS.minTapTarget, height: DS.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.6).onEnded { _ in clearNumber() })
            .opacity(phoneNumber.isEmpty ? 0 : 1)
            .disabled(phoneNumber.isEmpty)
            .accessibilityLabel("Delete")
            .accessibilityHint("Touch and hold to clear the number")
        }
        .frame(height: 64)
        .padding(.horizontal, DS.spacingM)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: phoneNumber)
    }

    /// Your saved contacts, one tap to fill in their number. (Debug builds used to show fake
    /// "Contact 1…5 / 555-000x" entries here; release builds showed nothing.)
    @ViewBuilder
    private var contactsSearchView: some View {
        let contacts = Array(ContactManager.shared.contacts.filter { $0.phone.filter(\.isNumber).count >= 7 }.prefix(10))
        if !contacts.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(contacts) { contact in
                        ContactQuickButton(name: contact.name, phone: contact.phone) { contactPhone in
                            phoneNumber = contactPhone.filter { $0.isNumber || $0 == "+" }
                        }
                    }
                }
                .padding(.horizontal, DS.spacingL)
            }
        } else {
            Color.clear
        }
    }

    // MARK: - Keys

    private func dialpadGrid(_ metrics: DialpadMetrics) -> some View {
        VStack(spacing: metrics.rowSpacing) {
            ForEach(0..<keys.count, id: \.self) { row in
                HStack(spacing: metrics.columnSpacing) {
                    ForEach(keys[row], id: \.0) { key in
                        EnhancedDialpadButton(number: key.0, letters: key.1, size: metrics.key) { addDigit(key.0) }
                    }
                }
            }
        }
    }
    
    // MARK: - Call button

    private func callButton(size: CGFloat) -> some View {
        Button(action: initiateCall) {
            Image(systemName: "phone.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(isValidPhoneNumber ? Color(red: 0.2, green: 0.8, blue: 0.35) : Color.white.opacity(0.18))
                )
                .background(
                    // Glowing pulse once the number is complete.
                    CallPulse(active: isValidPhoneNumber && !reduceMotion)
                )
                .shadow(color: isValidPhoneNumber ? Color.green.opacity(0.5) : .clear, radius: 14)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isValidPhoneNumber)
        .animation(.easeInOut(duration: 0.25), value: isValidPhoneNumber)
        .accessibilityLabel("Call")
        .accessibilityHint(isValidPhoneNumber ? "Choose an audio or video call" : "Enter a phone number first")
    }

    private var isValidPhoneNumber: Bool {
        let cleanedNumber = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        // Accept phone numbers with 7-15 digits (international standard)
        return cleanedNumber.count >= 7 && cleanedNumber.count <= 15
    }

    private func formatPhoneNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        // Handle different phone number lengths
        if cleaned.count == 10 {
            // US format: (123) 456-7890
            let areaCode = String(cleaned.prefix(3))
            let firstThree = String(cleaned.dropFirst(3).prefix(3))
            let lastFour = String(cleaned.dropFirst(6).prefix(4))
            return "(\(areaCode)) \(firstThree)-\(lastFour)"
        } else if cleaned.count == 11 && cleaned.hasPrefix("1") {
            // US with country code: +1 (123) 456-7890
            let areaCode = String(cleaned.dropFirst(1).prefix(3))
            let firstThree = String(cleaned.dropFirst(4).prefix(3))
            let lastFour = String(cleaned.dropFirst(7).prefix(4))
            return "+1 (\(areaCode)) \(firstThree)-\(lastFour)"
        } else if cleaned.count > 10 {
            // International format: +XX XXX XXX XXXX
            let countryCode = String(cleaned.prefix(cleaned.count - 10))
            let remaining = String(cleaned.dropFirst(countryCode.count))
            let formatted = remaining.enumerated().map { index, char in
                if index == 3 || index == 6 { return " \(char)" }
                return String(char)
            }.joined()
            return "+\(countryCode) \(formatted)"
        }

        return number
    }

    private func addDigit(_ digit: String) {
        guard phoneNumber.count < 20 else { return }
        phoneNumber += digit
        Haptics.tap()
    }

    private func deleteLastDigit() {
        guard !phoneNumber.isEmpty else { return }
        phoneNumber.removeLast()
        Haptics.tap()
    }

    private func clearNumber() {
        guard !phoneNumber.isEmpty else { return }
        phoneNumber = ""
        Haptics.warning()
    }

    private func initiateCall() {
        if isValidPhoneNumber {
            Haptics.tap()
            showCallOptions = true
        } else {
            Haptics.failure()
            withAnimation(.linear(duration: 0.35)) { isShaking = true }
            showInvalidNumberAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isShaking = false }
        }
    }

    private func makeCall(isVideo: Bool) {
        let digits = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        guard digits.filter(\.isNumber).count >= 7 else {
            showInvalidNumberAlert = true
            return
        }
        // Close the dial pad, then look up who owns the number and call it. (This used to create
        // a throwaway WebRTCService and call the phone number as if it were a user ID.)
        dismissDialpad()
        CallCoordinator.shared.startCall(toPhone: digits, isVideo: isVideo)
    }

    private func dismissDialpad() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Layout

/// Works out the key size and spacing from the space inside the safe area, so the keypad fits
/// from the iPhone SE to the Pro Max. Keys are never wider than a quarter of the screen,
/// never more than 80 pt, and small enough that all four rows, the number and the call
/// button fit in the height that is there.
struct DialpadMetrics {
    static let contactsHeight: CGFloat = 70
    static let numberHeight: CGFloat = 64
    static let headerHeight: CGFloat = DS.minTapTarget
    
    let key: CGFloat
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let gap: CGFloat
    let callGap: CGFloat
    let showsContacts: Bool
    
    init(size: CGSize) {
        let compact = size.height < 640                          // iPhone SE and similar
        topPadding = compact ? 4 : 12
        bottomPadding = compact ? 12 : 24
        gap = compact ? 4 : 12
        // Hide the contacts row only if it would squeeze the keys below a comfortable size.
        let fixedWithContacts = topPadding + Self.headerHeight + gap + Self.numberHeight
            + Self.contactsHeight + gap + bottomPadding
        let fixed = fixedWithContacts - Self.contactsHeight
        // Height the keypad needs for a key of size k: 4 rows + 3 row gaps (0.25k)
        // + call button (k) + gap above it (0.3k) = 6.05k.
        let heightUnits: CGFloat = 4 + 3 * 0.25 + 1 + 0.3
        let byWidth = size.width / 4
        let withContacts = (size.height - fixedWithContacts) / heightUnits
        showsContacts = withContacts >= 64
        let byHeight = (size.height - (showsContacts ? fixedWithContacts : fixed)) / heightUnits
        key = max(52, min(byWidth, byHeight, 80))
        columnSpacing = key * 0.4
        rowSpacing = key * 0.25
        callGap = key * 0.3
    }
}

// MARK: - Keypad button

/// One round frosted-glass key: big white number, small grey letters. Springs down on press
/// and gives a light haptic tap.
struct EnhancedDialpadButton: View {
    let number: String
    let letters: String
    /// Diameter of the key; the text scales with it (32 pt number and 10 pt letters at 80 pt).
    var size: CGFloat = 80
    let action: () -> Void

    private var scale: CGFloat { size / 80 }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(number)
                    .font(.system(size: (number == "*" ? 40 : 32) * scale, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .offset(y: number == "*" ? 6 * scale : 0)          // the asterisk glyph sits high
                    .frame(height: 38 * scale)

                Text(letters.isEmpty ? " " : letters)
                    .font(.system(size: max(9, 10 * scale), weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.55))
            }
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(
                Circle().stroke(
                    LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            )
            .contentShape(Circle())
        }
        .buttonStyle(DialKeyStyle())
        .accessibilityLabel(letters.isEmpty || letters == "+" ? number : "\(number), \(letters)")
    }
}

/// Press: shrink to 0.96 with a spring and light up the glass, like the iPhone keypad.
private struct DialKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? 0.18 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Two soft green rings that keep spreading out from the call button.
private struct CallPulse: View {
    let active: Bool
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { ring in
                Circle()
                    .stroke(Color.green.opacity(0.55), lineWidth: 3)
                    .scaleEffect(animate ? 1.45 : 1)
                    .opacity(animate ? 0 : 0.8)
                    .animation(
                        active
                            ? .easeOut(duration: 1.6).repeatForever(autoreverses: false).delay(Double(ring) * 0.8)
                            : .default,
                        value: animate)
            }
        }
        .opacity(active ? 1 : 0)
        .onAppear { animate = active }
        .onChange(of: active) { _, isActive in animate = isActive }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Side-to-side shake for an invalid number.
private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(shakes * .pi * 2), y: 0))
    }
}

// MARK: - Contact Quick Button
struct ContactQuickButton: View {
    let name: String
    let phone: String
    let onTap: (String) -> Void

    var body: some View {
        Button(action: { onTap(phone) }) {
            VStack(spacing: 4) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(name.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    )

                Text(name)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .frame(width: 60)
        }
        .buttonStyle(PressableStyle())
    }
}

struct EnhancedDialpadView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedDialpadView(isPresented: .constant(true))
    }
}
