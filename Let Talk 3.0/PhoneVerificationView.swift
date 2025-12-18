import SwiftUI
import UIKit

struct PhoneVerificationView: View {
    // MARK: - Properties
    @Binding var isPresented: Bool
    @Binding var isLoggedIn: Bool
    @EnvironmentObject var authManager: AuthManager
    
    // MARK: - State Variables
    @State private var selectedState = ""
    @State private var areaCode = ""
    @State private var selectedNumbers: [String] = []
    @State private var randomNumbers: [String] = []
    @State private var selectedAreaCodes: [String] = []
    @State private var numberSelectionEnabled = false
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var isVerifyingPhone = false
    @State private var errorMessage: String = ""
    
    // MARK: - UI State
    @State private var isStateDropdownOpen = false
    @State private var isAreaCodeDropdownOpen = false
    @State private var isNumbersDropdownOpen = false
    @State private var lockProgress: CGFloat = 0
    @State private var isLocked = false
    @State private var isLockAnimating = false
    @State private var showConfetti = false
    @State private var canNavigate = false
    @State private var pulseEffect = false
    @State private var animateBackground = false
    @State private var rotationEffect: Double = 0
    @State private var lockTimer: Timer?
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    // MARK: - State Data
    static let stateAreaCodes: [String: [String]] = [
        "Alabama": ["205", "251", "256", "334", "938"],
        "Alaska": ["907"],
        "Arizona": ["480", "520", "602", "623", "928"],
        "Arkansas": ["479", "501", "870"],
        "California": ["209", "213", "310", "323", "408", "415", "424", "442", "510", "530", "559", "562", "619", "626", "650", "657", "661", "669", "707", "714", "747", "760", "805", "818", "831", "858", "909", "916", "925", "949", "951"],
        "Colorado": ["303", "719", "720", "970"],
        "Connecticut": ["203", "475", "860", "959"],
        "Delaware": ["302"],
        "Florida": ["239", "305", "321", "352", "386", "407", "561", "727", "754", "772", "786", "813", "850", "863", "904", "941", "954"],
        "Georgia": ["229", "404", "470", "478", "678", "706", "762", "770", "912"],
        "Hawaii": ["808"],
        "Idaho": ["208", "986"],
        "Illinois": ["217", "224", "309", "312", "331", "618", "630", "708", "773", "779", "815", "847", "872"],
        "Indiana": ["219", "260", "317", "463", "574", "765", "812", "930"],
        "Iowa": ["319", "515", "563", "641", "712"],
        "Kansas": ["316", "620", "785", "913"],
        "Kentucky": ["270", "364", "502", "606", "859"],
        "Louisiana": ["225", "318", "337", "504", "985"],
        "Maine": ["207"],
        "Maryland": ["240", "301", "410", "443", "667"],
        "Massachusetts": ["339", "351", "413", "508", "617", "774", "781", "857", "978"],
        "Michigan": ["231", "248", "269", "313", "517", "586", "616", "734", "810", "906", "947", "989"],
        "Minnesota": ["218", "320", "507", "612", "651", "763", "952"],
        "Mississippi": ["228", "601", "662", "769"],
        "Missouri": ["314", "417", "573", "636", "660", "816"],
        "Montana": ["406"],
        "Nebraska": ["308", "402", "531"],
        "Nevada": ["702", "725", "775"],
        "New Hampshire": ["603"],
        "New Jersey": ["201", "551", "609", "732", "848", "856", "862", "908", "973"],
        "New Mexico": ["505", "575"],
        "New York": ["212", "315", "332", "347", "516", "518", "585", "607", "631", "646", "680", "716", "718", "845", "914", "917", "929", "934"],
        "North Carolina": ["252", "336", "704", "828", "910", "919", "980", "984"],
        "North Dakota": ["701"],
        "Ohio": ["216", "220", "234", "330", "380", "419", "440", "513", "567", "614", "740", "937"],
        "Oklahoma": ["405", "539", "580", "918"],
        "Oregon": ["458", "503", "541", "971"],
        "Pennsylvania": ["215", "267", "272", "412", "484", "570", "610", "717", "724", "814", "878"],
        "Rhode Island": ["401"],
        "South Carolina": ["803", "843", "864"],
        "South Dakota": ["605"],
        "Tennessee": ["423", "615", "629", "731", "865", "901", "931"],
        "Texas": ["210", "214", "254", "281", "325", "346", "361", "409", "430", "432", "469", "512", "682", "713", "737", "806", "817", "830", "832", "903", "915", "936", "940", "956", "972", "979"],
        "Utah": ["385", "435", "801"],
        "Vermont": ["802"],
        "Virginia": ["276", "434", "540", "571", "703", "757", "804"],
        "Washington": ["206", "253", "360", "425", "509", "564"],
        "West Virginia": ["304", "681"],
        "Wisconsin": ["262", "414", "534", "608", "715", "920"],
        "Wyoming": ["307"]
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .purple, .pink]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "phone.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                            
                            Text("Get Your Phone Number")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Choose your state, area code, and get 5 random numbers to pick from")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        
                        // Steps Progress
                        StepsProgressView(
                            currentStep: getCurrentStep(),
                            steps: ["State", "Area Code", "Numbers", "Verify"]
                        )
                        
                        // Main Content
                        VStack(spacing: 20) {
                            // State Selection
                            stateSelectionSection
                            
                            // Area Code Selection
                            if !selectedState.isEmpty {
                                areaCodeSection
                            }
                            
                            // Phone Number Display
                            if !areaCode.isEmpty {
                                phoneNumberDisplay
                            }
                            
                            // Number Selection
                            if !areaCode.isEmpty {
                                numberSelectionSection
                            }
                            
                            // Lock In Button
                            if !selectedState.isEmpty && !areaCode.isEmpty && !selectedNumbers.isEmpty {
                                lockInButton
                            }
                            
                            // Navigation Button (appears after lock in)
                            if canNavigate {
                                navigationButton
                            }
                            
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Confetti overlay
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
    
    private func getCurrentStep() -> Int {
        if selectedState.isEmpty { return 0 }
        if areaCode.isEmpty { return 1 }
        if selectedNumbers.isEmpty { return 2 }
        return 3
    }
    
    private var stateSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select State:")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Button(action: {
                if !isLocked {
                    withAnimation(.spring()) {
                        isStateDropdownOpen.toggle()
                    }
                }
            }) {
                HStack {
                    Text(selectedState.isEmpty ? "Select State" : selectedState)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .rotationEffect(isStateDropdownOpen ? .degrees(180) : .degrees(0))
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
            }
            .disabled(isLocked)
            
            if isStateDropdownOpen {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(PhoneVerificationView.stateAreaCodes.keys).sorted(), id: \.self) { state in
                            Button(action: { selectState(state) }) {
                                HStack {
                                    Text(state)
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                    Spacer()
                                    if selectedState == state {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(selectedState == state ? Color.blue.opacity(0.1) : Color.white)
                            }
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 250)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
            }
        }
    }
    
    private var areaCodeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Select Area Code:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    if !isLocked {
                        withAnimation(.spring()) {
                            isAreaCodeDropdownOpen.toggle()
                        }
                    }
                }) {
                    HStack {
                        Text(areaCode.isEmpty ? "Select Area Code" : "Change Area Code")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .rotationEffect(isAreaCodeDropdownOpen ? .degrees(180) : .degrees(0))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isLocked ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
                .disabled(isLocked)
            }
            
            if isAreaCodeDropdownOpen {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(selectedAreaCodes, id: \.self) { code in
                            Button(action: { selectAreaCode(code) }) {
                                Text(code)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundColor(areaCode == code ? .white : .blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(areaCode == code ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(20)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                .padding(8)
            }
            
            if !areaCode.isEmpty {
                Text("Selected: \(areaCode)")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(20)
            }
        }
    }
    
    private var phoneNumberDisplay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Phone Number:")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Text(formattedPhoneNumber)
                .font(.title2.bold())
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
    
    private var numberSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select 1 Number from 5 Options:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    if !isLocked {
                        withAnimation(.spring()) {
                            isNumbersDropdownOpen.toggle()
                            generateRandomNumbers()
                        }
                    }
                }) {
                    Text(selectedNumbers.isEmpty ? "Select Number" : "Change Number")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isLocked ? Color.gray : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
                .disabled(isLocked)
            }
            
            if isNumbersDropdownOpen {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(randomNumbers, id: \.self) { number in
                            Button(action: { selectNumber(number) }) {
                                Text(number)
                                    .font(.title3.bold())
                                    .foregroundColor(selectedNumbers.contains(number) ? .white : .purple)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedNumbers.contains(number) ? Color.purple : Color.purple.opacity(0.1))
                                    .cornerRadius(25)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
            }
            
            if !selectedNumbers.isEmpty {
                Text("Selected: \(selectedNumbers.joined(separator: ", "))")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(20)
            }
        }
    }
    
    private var lockInButton: some View {
        ZStack(alignment: .leading) {
            // Background
            Capsule()
                .fill(
                    (!selectedState.isEmpty && !areaCode.isEmpty && !selectedNumbers.isEmpty)
                    ? Color.gray.opacity(0.6)
                    : Color.gray.opacity(0.3)
                )
            
            // Progress fill with glow effect
            Capsule()
                .fill(Color.green)
                .frame(width: UIScreen.main.bounds.width * 0.8 * (lockProgress / 100))
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.5), lineWidth: lockProgress > 0 ? 2 : 0)
                        .blur(radius: lockProgress > 50 ? 4 : 0)
                )
                .animation(.linear(duration: 0.1), value: lockProgress)
            
            // Button content
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    Text(isLocked ? "Locked In" : "Hold to Lock In")
                        .font(.headline)
                    Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                Spacer()
            }
            .foregroundColor(.white)
            .frame(height: 50)
        }
        .frame(height: 50)
        .cornerRadius(25)
        .disabled(selectedState.isEmpty || areaCode.isEmpty || selectedNumbers.isEmpty || isLocked)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startLockTimer() }
                .onEnded { _ in stopLockTimer() }
        )
    }
    
    private var navigationButton: some View {
        Button(action: {
            completePhoneVerification()
        }) {
            HStack {
                Text("Continue to App")
                    .font(.headline)
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    private func generateRandomNumbers() {
        var numbers: [String] = []
        for _ in 0..<5 { // Generate 5 random numbers
            var randomNum = ""
            for _ in 0..<7 {
                randomNum += String(Int.random(in: 0...9))
            }
            // Format as XXX-XXXX
            randomNum = "\(randomNum.prefix(3))-\(randomNum.suffix(4))"
            numbers.append(randomNum)
        }
        randomNumbers = numbers.sorted()
    }
    
    private func selectNumber(_ number: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedNumbers.contains(number) {
                selectedNumbers.removeAll { $0 == number }
            } else if selectedNumbers.count < 1 { // Allow only one number selection
                selectedNumbers.append(number)
                isNumbersDropdownOpen = false
            }
        }
    }
    
    private var formattedPhoneNumber: String {
        if selectedState.isEmpty || areaCode.isEmpty {
            return "Select state and area code"
        }
        if selectedNumbers.isEmpty {
            return "(\(areaCode)) Select 7 digits"
        }
        return "(\(areaCode)) \(selectedNumbers.joined(separator: "-"))"
    }
    
    private func completePhoneVerification() {
        // Show confetti first
        withAnimation(.spring()) {
            showConfetti = true
            canNavigate = true
        }
        
        // Create the full phone number
        let fullPhoneNumber = "(\(areaCode)) \(selectedNumbers.joined(separator: "-"))"
        
        Task {
            do {
                try await authManager.completePhoneVerification(phoneNumber: fullPhoneNumber)
                
                await MainActor.run {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isPresented = false
                        isLoggedIn = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func startLockTimer() {
        guard !isLocked && !selectedState.isEmpty && !areaCode.isEmpty && !selectedNumbers.isEmpty else { return }
        
        lockProgress = 0
        lockTimer?.invalidate()
        
        lockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            lockProgress += 1.25 // 100% / 8 seconds = 12.5% per second
            
            if lockProgress >= 100 {
                timer.invalidate()
                isLocked = true
                canNavigate = true
                lockProgress = 100
            }
        }
    }
    
    private func stopLockTimer() {
        guard !isLocked else { return }
        
        lockTimer?.invalidate()
        
        if lockProgress < 100 {
            withAnimation { lockProgress = 0 }
        }
    }
    
    private func selectAreaCode(_ code: String) {
        withAnimation(.spring()) {
            areaCode = code
            generateRandomNumbers()
            numberSelectionEnabled = true
        }
    }
    
    private func selectState(_ state: String) {
        withAnimation(.spring()) {
            selectedState = state
            areaCode = ""
            selectedNumbers = []
            isStateDropdownOpen = false
            isLocked = false
            lockProgress = 0
            canNavigate = false
            
            // Update area codes for selected state
            selectedAreaCodes = PhoneVerificationView.stateAreaCodes[state] ?? []
        }
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.9))
            .cornerRadius(12)
            .font(.body)
    }
}

// MARK: - Steps Progress View
struct StepsProgressView: View {
    let currentStep: Int
    let steps: [String]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 30, height: 30)
                        
                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.blue)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(index == currentStep ? .blue : .white.opacity(0.6))
                        }
                    }
                    
                    Text(steps[index])
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep ? Color.white : Color.white.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var isAnimating = false
    let colors: [Color] = [.blue, .purple, .pink, .orange, .yellow, .green]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<3) { layer in
                    ForEach(0..<40) { i in
                        let scale = [1.0, 0.8, 0.6][layer]
                        let rotation = Double.random(in: 0...360)
                        let position = randomPosition(in: geometry.size)
                        let color = colors.randomElement() ?? .blue
                        
                        ConfettiPiece(
                            position: position,
                            color: color,
                            rotation: rotation,
                            size: CGSize(width: 8 * scale, height: 8 * scale)
                        )
                        .offset(y: isAnimating ? geometry.size.height + 100 : -100)
                        .animation(
                            Animation.linear(duration: Double.random(in: 2...4))
                                .repeatForever(autoreverses: false)
                                .delay(Double.random(in: 0...2)),
                            value: isAnimating
                        )
                    }
                }
            }
            .onAppear {
                isAnimating = true
            }
        }
    }
    
    private func randomPosition(in size: CGSize) -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: 0...size.width),
            y: CGFloat.random(in: 0...size.height)
        )
    }
}

struct ConfettiPiece: View {
    let position: CGPoint
    let color: Color
    let rotation: Double
    let size: CGSize
    
    var body: some View {
        Group {
            Rectangle()
                .fill(color)
                .frame(width: size.width, height: size.height)
                .rotationEffect(.degrees(rotation))
                .position(position)
            
            Circle()
                .fill(color)
                .frame(width: size.width, height: size.width)
                .position(
                    x: position.x + CGFloat.random(in: -20...20),
                    y: position.y + CGFloat.random(in: -20...20)
                )
        }
        .opacity(0.7)
    }
}

// MARK: - Custom Button Style
// ScaleButtonStyle is already defined in UnifiedTranslationComponents.swift

#Preview {
    PhoneVerificationView(isPresented: .constant(true), isLoggedIn: .constant(false))
        .environmentObject(AuthManager.shared)
}
