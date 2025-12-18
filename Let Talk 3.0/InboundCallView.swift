import SwiftUI
import AVFoundation

struct InboundCallView: View {
    let callerPhoneNumber: String
    let isVideo: Bool
    @StateObject private var contactManager = ContactManager.shared
    @State private var callerContact: Contact?
    @State private var isAnimating = false
    @State private var showCallScreen = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background with gradient
            LinearGradient(
                gradient: Gradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Caller Information
                VStack(spacing: 20) {
                    // Profile Image
                    if let contact = callerContact {
                        ProfileImageView(
                            imageURL: contact.imageURL,
                            placeholderText: contact.initials
                        )
                        .frame(width: 150, height: 150)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    } else {
                        // Default profile for unknown caller
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 150, height: 150)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    }
                    
                    // Caller Name or Phone Number
                    VStack(spacing: 8) {
                        Text(callerContact?.name ?? formatPhoneNumber(callerPhoneNumber))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if callerContact == nil {
                            Text("Unknown Caller")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            Text(formatPhoneNumber(callerPhoneNumber))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Text(isVideo ? "Video Call" : "Voice Call")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                }
                
                Spacer()
                
                // Call Controls
                HStack(spacing: 50) {
                    // Decline Button
                    Button(action: declineCall) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        .shadow(radius: 5)
                    }
                    
                    // Accept Button
                    Button(action: acceptCall) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: isVideo ? "video.fill" : "phone.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        .shadow(radius: 5)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isAnimating = true
            findCallerContact()
        }
        .fullScreenCover(isPresented: $showCallScreen) {
            if let contact = callerContact {
                CallView(contact: contact, isVideo: isVideo)
            }
        }
    }
    
    private func findCallerContact() {
        // Search for contact by phone number
        callerContact = contactManager.contacts.first { contact in
            // Normalize phone numbers for comparison
            let normalizedCaller = normalizePhoneNumber(callerPhoneNumber)
            let normalizedContact = normalizePhoneNumber(contact.phone)
            return normalizedCaller == normalizedContact
        }
    }
    
    private func normalizePhoneNumber(_ phone: String) -> String {
        // Remove all non-digit characters
        return phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
    }
    
    private func formatPhoneNumber(_ phone: String) -> String {
        let digits = normalizePhoneNumber(phone)
        
        if digits.count == 10 {
            // Format as (XXX) XXX-XXXX
            let areaCode = String(digits.prefix(3))
            let firstThree = String(digits.dropFirst(3).prefix(3))
            let lastFour = String(digits.suffix(4))
            return "(\(areaCode)) \(firstThree)-\(lastFour)"
        } else if digits.count == 11 && digits.hasPrefix("1") {
            // Format as +1 (XXX) XXX-XXXX
            let areaCode = String(digits.dropFirst(1).prefix(3))
            let firstThree = String(digits.dropFirst(4).prefix(3))
            let lastFour = String(digits.suffix(4))
            return "+1 (\(areaCode)) \(firstThree)-\(lastFour)"
        } else {
            // Return original if can't format
            return phone
        }
    }
    
    private func acceptCall() {
        showCallScreen = true
    }
    
    private func declineCall() {
        // End the call
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Inbound Call Manager
class InboundCallManager: ObservableObject {
    static let shared = InboundCallManager()
    
    @Published var isIncomingCall = false
    @Published var incomingCallerPhone: String = ""
    @Published var incomingCallIsVideo: Bool = false
    
    private init() {}
    
    func showIncomingCall(from phoneNumber: String, isVideo: Bool = false) {
        Task { @MainActor in
            self.incomingCallerPhone = phoneNumber
            self.incomingCallIsVideo = isVideo
            self.isIncomingCall = true
        }
    }
    
    func dismissIncomingCall() {
        Task { @MainActor in
            self.isIncomingCall = false
            self.incomingCallerPhone = ""
            self.incomingCallIsVideo = false
        }
    }
}

// MARK: - Inbound Call Overlay
struct InboundCallOverlay: View {
    @StateObject private var callManager = InboundCallManager.shared
    
    var body: some View {
        if callManager.isIncomingCall {
            InboundCallView(
                callerPhoneNumber: callManager.incomingCallerPhone,
                isVideo: callManager.incomingCallIsVideo
            )
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .zIndex(1000)
        }
    }
}

struct InboundCallView_Previews: PreviewProvider {
    static var previews: some View {
        InboundCallView(
            callerPhoneNumber: "+1 (555) 123-4567",
            isVideo: true
        )
    }
}
