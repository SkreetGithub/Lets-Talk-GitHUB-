import SwiftUI

struct DialpadPopoverView: View {
    @Binding var isPresented: Bool
    @State private var phoneNumber = ""
    @State private var showCallOptions = false
    @State private var isShaking = false
    @State private var showInvalidNumberAlert = false
    
    var body: some View {
        ZStack {
            // Blurred Background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissDialpad()
                }
            
            // Dialpad Content
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    // Phone Number Display
                    phoneNumberDisplay
                    
                    // Dialpad Grid
                    dialpadGrid
                    
                    // Call Buttons
                    callButtons
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .scaleEffect(isShaking ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true), value: isShaking)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                // Animate in
            }
        }
        .actionSheet(isPresented: $showCallOptions) {
            ActionSheet(title: Text("Call Options"), buttons: [
                .default(Text("Audio Call")) { makeCall(isVideo: false) },
                .default(Text("Video Call")) { makeCall(isVideo: true) },
                .cancel()
            ])
        }
        .alert("Invalid Number", isPresented: $showInvalidNumberAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter a valid 10-digit phone number")
        }
    }
    
    private var phoneNumberDisplay: some View {
        VStack(spacing: 8) {
            Text(phoneNumber.isEmpty ? "Enter number" : phoneNumber)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            
            if !phoneNumber.isEmpty {
                Button("Clear") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        phoneNumber = ""
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
    
    private var dialpadGrid: some View {
        VStack(spacing: 16) {
            // Row 1: 1, 2, 3
            HStack(spacing: 20) {
                DialpadButton(number: "1", letters: "")
                DialpadButton(number: "2", letters: "ABC")
                DialpadButton(number: "3", letters: "DEF")
            }
            
            // Row 2: 4, 5, 6
            HStack(spacing: 20) {
                DialpadButton(number: "4", letters: "GHI")
                DialpadButton(number: "5", letters: "JKL")
                DialpadButton(number: "6", letters: "MNO")
            }
            
            // Row 3: 7, 8, 9
            HStack(spacing: 20) {
                DialpadButton(number: "7", letters: "PQRS")
                DialpadButton(number: "8", letters: "TUV")
                DialpadButton(number: "9", letters: "WXYZ")
            }
            
            // Row 4: *, 0, #
            HStack(spacing: 20) {
                DialpadButton(number: "*", letters: "")
                DialpadButton(number: "0", letters: "+")
                DialpadButton(number: "#", letters: "")
            }
        }
    }
    
    private var callButtons: some View {
        HStack(spacing: 20) {
            // Delete Button
            Button(action: deleteLastDigit) {
                Image(systemName: "delete.left.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(Color(.systemGray5))
                    )
            }
            .disabled(phoneNumber.isEmpty)
            .opacity(phoneNumber.isEmpty ? 0.3 : 1.0)
            
            // Call Button
            Button(action: initiateCall) {
                Image(systemName: "phone.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(isValidPhoneNumber ? Color.green : Color.gray)
                    )
            }
            .disabled(!isValidPhoneNumber)
            .scaleEffect(isValidPhoneNumber ? 1.0 : 0.9)
            .animation(.easeInOut(duration: 0.2), value: isValidPhoneNumber)
        }
    }
    
    private var isValidPhoneNumber: Bool {
        let cleanedNumber = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return cleanedNumber.count == 10
    }
    
    private func addDigit(_ digit: String) {
        withAnimation(.easeInOut(duration: 0.1)) {
            phoneNumber += digit
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func deleteLastDigit() {
        if !phoneNumber.isEmpty {
            withAnimation(.easeInOut(duration: 0.1)) {
                phoneNumber.removeLast()
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func initiateCall() {
        if isValidPhoneNumber {
            showCallOptions = true
        } else {
            // Shake animation for invalid number
            withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
                isShaking = true
            }
            
            // Show alert
            showInvalidNumberAlert = true
            
            // Reset shake animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isShaking = false
            }
        }
    }
    
    private func makeCall(isVideo: Bool) {
        // Implement call functionality
        // This would typically navigate to CallView
        dismissDialpad()
    }
    
    private func dismissDialpad() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Dialpad Button
struct DialpadButton: View {
    let number: String
    let letters: String
    @State private var isPressed = false
    
    var body: some View {
        Button(action: { addDigit(number) }) {
            VStack(spacing: 4) {
                Text(number)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if !letters.isEmpty {
                    Text(letters)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 60, height: 60)
            .background(
                Circle()
                    .fill(isPressed ? Color(.systemGray4) : Color(.systemGray6))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private func addDigit(_ digit: String) {
        // This will be handled by the parent view
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Enhanced Dialpad with Contacts
struct EnhancedDialpadPopoverView: View {
    @Binding var isPresented: Bool
    @State private var phoneNumber = ""
    @State private var showCallOptions = false
    @State private var isShaking = false
    @State private var showInvalidNumberAlert = false
    @State private var searchText = ""
    @State private var showContacts = false
    
    var body: some View {
        ZStack {
            // Blurred Background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissDialpad()
                }
            
            // Dialpad Content
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    // Header with close button
                    HStack {
                        Text("Dial")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: dismissDialpad) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Phone Number Display
                    phoneNumberDisplay
                    
                    // Contacts Search (if number is being entered)
                    if !phoneNumber.isEmpty {
                        contactsSearchView
                    }
                    
                    // Dialpad Grid
                    dialpadGrid
                    
                    // Call Buttons
                    callButtons
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .scaleEffect(isShaking ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true), value: isShaking)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                // Animate in
            }
        }
        .actionSheet(isPresented: $showCallOptions) {
            ActionSheet(title: Text("Call Options"), buttons: [
                .default(Text("Audio Call")) { makeCall(isVideo: false) },
                .default(Text("Video Call")) { makeCall(isVideo: true) },
                .cancel()
            ])
        }
        .alert("Invalid Number", isPresented: $showInvalidNumberAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter a valid 10-digit phone number")
        }
    }
    
    private var phoneNumberDisplay: some View {
        VStack(spacing: 8) {
            Text(phoneNumber.isEmpty ? "Enter number" : formatPhoneNumber(phoneNumber))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            
            if !phoneNumber.isEmpty {
                Button("Clear") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        phoneNumber = ""
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
    
    private var contactsSearchView: some View {
        VStack(spacing: 8) {
            Text("Recent Contacts")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Mock recent contacts - in real app, this would be actual contacts
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5) { index in
                        Button(action: { 
                            phoneNumber = "555-000\(index + 1)"
                        }) {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(String("Contact \(index + 1)".prefix(1)))
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    )
                                
                                Text("Contact \(index + 1)")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            .frame(width: 60)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var dialpadGrid: some View {
        VStack(spacing: 16) {
            // Row 1: 1, 2, 3
            HStack(spacing: 20) {
                DialpadButton(number: "1", letters: "")
                DialpadButton(number: "2", letters: "ABC")
                DialpadButton(number: "3", letters: "DEF")
            }
            
            // Row 2: 4, 5, 6
            HStack(spacing: 20) {
                DialpadButton(number: "4", letters: "GHI")
                DialpadButton(number: "5", letters: "JKL")
                DialpadButton(number: "6", letters: "MNO")
            }
            
            // Row 3: 7, 8, 9
            HStack(spacing: 20) {
                DialpadButton(number: "7", letters: "PQRS")
                DialpadButton(number: "8", letters: "TUV")
                DialpadButton(number: "9", letters: "WXYZ")
            }
            
            // Row 4: *, 0, #
            HStack(spacing: 20) {
                DialpadButton(number: "*", letters: "")
                DialpadButton(number: "0", letters: "+")
                DialpadButton(number: "#", letters: "")
            }
        }
    }
    
    private var callButtons: some View {
        HStack(spacing: 20) {
            // Delete Button
            Button(action: deleteLastDigit) {
                Image(systemName: "delete.left.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(Color(.systemGray5))
                    )
            }
            .disabled(phoneNumber.isEmpty)
            .opacity(phoneNumber.isEmpty ? 0.3 : 1.0)
            
            // Call Button
            Button(action: initiateCall) {
                Image(systemName: "phone.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(isValidPhoneNumber ? Color.green : Color.gray)
                    )
            }
            .disabled(!isValidPhoneNumber)
            .scaleEffect(isValidPhoneNumber ? 1.0 : 0.9)
            .animation(.easeInOut(duration: 0.2), value: isValidPhoneNumber)
        }
    }
    
    private var isValidPhoneNumber: Bool {
        let cleanedNumber = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return cleanedNumber.count == 10
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if cleaned.count >= 10 {
            let areaCode = String(cleaned.prefix(3))
            let firstThree = String(cleaned.dropFirst(3).prefix(3))
            let lastFour = String(cleaned.dropFirst(6).prefix(4))
            return "(\(areaCode)) \(firstThree)-\(lastFour)"
        }
        return number
    }
    
    private func addDigit(_ digit: String) {
        withAnimation(.easeInOut(duration: 0.1)) {
            phoneNumber += digit
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func deleteLastDigit() {
        if !phoneNumber.isEmpty {
            withAnimation(.easeInOut(duration: 0.1)) {
                phoneNumber.removeLast()
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func initiateCall() {
        if isValidPhoneNumber {
            showCallOptions = true
        } else {
            // Shake animation for invalid number
            withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
                isShaking = true
            }
            
            // Show alert
            showInvalidNumberAlert = true
            
            // Reset shake animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isShaking = false
            }
        }
    }
    
    private func makeCall(isVideo: Bool) {
        // Implement call functionality
        // This would typically navigate to CallView
        dismissDialpad()
    }
    
    private func dismissDialpad() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// ContactQuickButton is now defined in EnhancedDialpadView.swift

struct DialpadPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        DialpadPopoverView(isPresented: .constant(true))
    }
}
