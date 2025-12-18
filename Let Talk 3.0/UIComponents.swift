import SwiftUI
import Combine

// MARK: - Dial Pad Component
struct DialPadView: View {
    @State private var phoneNumber = ""
    @State private var isCalling = false
    @State private var showingCallOptions = false
    let onCall: (String) -> Void
    
    private let dialPadNumbers = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["*", "0", "#"]
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Phone Number Display
            VStack(spacing: 8) {
                Text(formatPhoneNumber(phoneNumber))
                    .font(.system(size: 32, weight: .light, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(minHeight: 40)
                
                if phoneNumber.isEmpty {
                    Text("Enter phone number")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical)
            
            // Dial Pad
            VStack(spacing: 16) {
                ForEach(dialPadNumbers, id: \.self) { row in
                    HStack(spacing: 16) {
                        ForEach(row, id: \.self) { number in
                            DialPadButton(number: number) {
                                dialNumber(number)
                            }
                        }
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: 20) {
                // Clear Button
                Button(action: clearNumber) {
                    Image(systemName: "delete.left")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .disabled(phoneNumber.isEmpty)
                
                // Call Button
                Button(action: {
                    if phoneNumber.count >= 10 {
                        showingCallOptions = true
                    }
                }) {
                    Image(systemName: "phone.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(phoneNumber.count >= 10 ? Color.green : Color.gray)
                        .clipShape(Circle())
                }
                .disabled(phoneNumber.count < 10)
                
                // Paste Button
                Button(action: pasteNumber) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top)
        }
        .padding()
        .actionSheet(isPresented: $showingCallOptions) {
            ActionSheet(
                title: Text("Call Options"),
                message: Text("Choose call type"),
                buttons: [
                    .default(Text("Audio Call")) {
                        onCall(phoneNumber)
                    },
                    .default(Text("Video Call")) {
                        onCall(phoneNumber)
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private func dialNumber(_ number: String) {
        phoneNumber += number
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func clearNumber() {
        if !phoneNumber.isEmpty {
            phoneNumber.removeLast()
        }
    }
    
    private func pasteNumber() {
        if let clipboardContent = UIPasteboard.general.string {
            let cleanedNumber = clipboardContent.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
            phoneNumber = cleanedNumber
        }
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        if number.isEmpty { return "" }
        
        let cleaned = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        if cleaned.count <= 3 {
            return cleaned
        } else if cleaned.count <= 6 {
            return "(\(cleaned.prefix(3))) \(cleaned.dropFirst(3))"
        } else if cleaned.count <= 10 {
            return "(\(cleaned.prefix(3))) \(cleaned.dropFirst(3).prefix(3))-\(cleaned.dropFirst(6))"
        } else {
            return "+\(cleaned.prefix(1)) (\(cleaned.dropFirst(1).prefix(3))) \(cleaned.dropFirst(4).prefix(3))-\(cleaned.dropFirst(7))"
        }
    }
}

struct DialPadButton: View {
    let number: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(number)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.primary)
                
                if number != "*" && number != "#" {
                    Text(getLetterMapping(for: number))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)
            .background(Color(.systemGray6))
            .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getLetterMapping(for number: String) -> String {
        switch number {
        case "2": return "ABC"
        case "3": return "DEF"
        case "4": return "GHI"
        case "5": return "JKL"
        case "6": return "MNO"
        case "7": return "PQRS"
        case "8": return "TUV"
        case "9": return "WXYZ"
        default: return ""
        }
    }
}

// MARK: - Phone Number Generator
struct PhoneNumberGeneratorView: View {
    @State private var selectedCountry = "+1"
    @State private var selectedAreaCode = ""
    @State private var generatedNumbers: [String] = []
    @State private var showingNumbers = false
    let onSelect: (String) -> Void
    
    private let countries = [
        ("+1", "US/Canada"),
        ("+44", "UK"),
        ("+33", "France"),
        ("+49", "Germany"),
        ("+39", "Italy"),
        ("+34", "Spain"),
        ("+81", "Japan"),
        ("+86", "China"),
        ("+91", "India")
    ]
    
    private let areaCodes: [String: [String]] = [
        "+1": ["201", "202", "203", "205", "206", "207", "208", "209", "210", "212", "213", "214", "215", "216", "217", "218", "219", "220", "223", "224", "225", "228", "229", "231", "234", "239", "240", "248", "251", "252", "253", "254", "256", "260", "262", "267", "269", "270", "272", "276", "281", "301", "302", "303", "304", "305", "307", "308", "309", "310", "312", "313", "314", "315", "316", "317", "318", "319", "320", "321", "323", "325", "330", "331", "334", "336", "337", "339", "340", "341", "347", "351", "352", "360", "361", "364", "380", "385", "386", "401", "402", "404", "405", "406", "407", "408", "409", "410", "412", "413", "414", "415", "417", "419", "423", "424", "425", "430", "432", "434", "435", "440", "442", "443", "445", "447", "458", "463", "469", "470", "475", "478", "479", "480", "484", "501", "502", "503", "504", "505", "507", "508", "509", "510", "512", "513", "515", "516", "517", "518", "520", "530", "531", "534", "539", "540", "541", "551", "559", "561", "562", "563", "564", "567", "570", "571", "573", "574", "575", "580", "585", "586", "601", "602", "603", "605", "606", "607", "608", "609", "610", "612", "614", "615", "616", "617", "618", "619", "620", "623", "626", "628", "629", "630", "631", "636", "641", "646", "650", "651", "657", "660", "661", "662", "667", "669", "678", "681", "682", "701", "702", "703", "704", "706", "707", "708", "712", "713", "714", "715", "716", "717", "718", "719", "720", "724", "725", "727", "731", "732", "734", "737", "740", "743", "747", "754", "757", "760", "762", "763", "765", "769", "770", "772", "773", "774", "775", "779", "781", "785", "786", "801", "802", "803", "804", "805", "806", "808", "810", "812", "813", "814", "815", "816", "817", "818", "828", "830", "831", "832", "843", "845", "847", "848", "850", "856", "857", "858", "859", "860", "862", "863", "864", "865", "870", "872", "878", "901", "903", "904", "906", "907", "908", "909", "910", "912", "913", "914", "915", "916", "917", "918", "919", "920", "925", "928", "929", "930", "931", "934", "936", "937", "938", "940", "941", "947", "949", "951", "952", "954", "956", "959", "970", "971", "972", "973", "975", "978", "979", "980", "984", "985", "989"],
        "+44": ["11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "23", "24", "28", "29", "113", "114", "115", "116", "117", "118", "121", "122", "123", "124", "125", "126", "127", "128", "129", "130", "131", "132", "133", "134", "135", "136", "137", "138", "139", "141", "142", "143", "144", "145", "146", "147", "148", "149", "150", "151", "152", "153", "154", "155", "156", "157", "158", "159", "160", "161", "162", "163", "164", "165", "166", "167", "168", "169", "170", "171", "172", "173", "174", "175", "176", "177", "178", "179", "180", "181", "182", "183", "184", "185", "186", "187", "188", "189", "190", "191", "192", "193", "194", "195", "196", "197", "198", "199"],
        "+33": ["1", "2", "3", "4", "5", "6", "7", "8", "9"],
        "+49": ["30", "40", "69", "89", "221", "231", "234", "251", "261", "271", "341", "351", "371", "421", "431", "441", "451", "461", "471", "481", "491", "511", "521", "531", "541", "551", "561", "571", "581", "591", "611", "621", "631", "641", "651", "661", "671", "681", "691", "711", "721", "731", "741", "751", "761", "771", "781", "791", "811", "821", "831", "841", "851", "861", "871", "881", "891"],
        "+39": ["2", "6", "10", "11", "15", "19", "30", "31", "35", "39", "40", "41", "45", "50", "51", "55", "59", "70", "71", "75", "79", "80", "81", "85", "89", "90", "91", "95", "99"],
        "+34": ["91", "93", "94", "95", "96", "97", "98"],
        "+81": ["3", "6", "11", "22", "27", "29", "42", "43", "44", "45", "47", "48", "52", "53", "54", "55", "58", "59", "72", "75", "76", "77", "78", "82", "83", "84", "86", "87", "88", "92", "93", "95", "96", "97", "98", "99"],
        "+86": ["10", "20", "21", "22", "23", "24", "25", "27", "28", "29", "311", "351", "371", "431", "451", "471", "531", "551", "571", "591", "731", "771", "851", "871", "891", "931", "951", "971"],
        "+91": ["11", "22", "33", "44", "55", "66", "77", "80", "120", "124", "129", "135", "141", "160", "172", "175", "180", "186", "191", "194", "202", "204", "212", "214", "224", "231", "233", "240", "251", "253", "261", "265", "271", "275", "281", "285", "291", "294", "297", "301", "302", "303", "304", "305", "306", "307", "308", "309", "311", "312", "313", "314", "315", "316", "317", "318", "319", "320", "321", "322", "323", "324", "325", "326", "327", "328", "329", "330", "331", "332", "333", "334", "335", "336", "337", "338", "339", "340", "341", "342", "343", "344", "345", "346", "347", "348", "349", "350", "351", "352", "353", "354", "355", "356", "357", "358", "359", "360", "361", "362", "363", "364", "365", "366", "367", "368", "369", "370", "371", "372", "373", "374", "375", "376", "377", "378", "379", "380", "381", "382", "383", "384", "385", "386", "387", "388", "389", "390", "391", "392", "393", "394", "395", "396", "397", "398", "399", "400", "401", "402", "403", "404", "405", "406", "407", "408", "409", "410", "411", "412", "413", "414", "415", "416", "417", "418", "419", "420", "421", "422", "423", "424", "425", "426", "427", "428", "429", "430", "431", "432", "433", "434", "435", "436", "437", "438", "439", "440", "441", "442", "443", "444", "445", "446", "447", "448", "449", "450", "451", "452", "453", "454", "455", "456", "457", "458", "459", "460", "461", "462", "463", "464", "465", "466", "467", "468", "469", "470", "471", "472", "473", "474", "475", "476", "477", "478", "479", "480", "481", "482", "483", "484", "485", "486", "487", "488", "489", "490", "491", "492", "493", "494", "495", "496", "497", "498", "499", "500", "501", "502", "503", "504", "505", "506", "507", "508", "509", "510", "511", "512", "513", "514", "515", "516", "517", "518", "519", "520", "521", "522", "523", "524", "525", "526", "527", "528", "529", "530", "531", "532", "533", "534", "535", "536", "537", "538", "539", "540", "541", "542", "543", "544", "545", "546", "547", "548", "549", "550", "551", "552", "553", "554", "555", "556", "557", "558", "559", "560", "561", "562", "563", "564", "565", "566", "567", "568", "569", "570", "571", "572", "573", "574", "575", "576", "577", "578", "579", "580", "581", "582", "583", "584", "585", "586", "587", "588", "589", "590", "591", "592", "593", "594", "595", "596", "597", "598", "599", "600", "601", "602", "603", "604", "605", "606", "607", "608", "609", "610", "611", "612", "613", "614", "615", "616", "617", "618", "619", "620", "621", "622", "623", "624", "625", "626", "627", "628", "629", "630", "631", "632", "633", "634", "635", "636", "637", "638", "639", "640", "641", "642", "643", "644", "645", "646", "647", "648", "649", "650", "651", "652", "653", "654", "655", "656", "657", "658", "659", "660", "661", "662", "663", "664", "665", "666", "667", "668", "669", "670", "671", "672", "673", "674", "675", "676", "677", "678", "679", "680", "681", "682", "683", "684", "685", "686", "687", "688", "689", "690", "691", "692", "693", "694", "695", "696", "697", "698", "699", "700", "701", "702", "703", "704", "705", "706", "707", "708", "709", "710", "711", "712", "713", "714", "715", "716", "717", "718", "719", "720", "721", "722", "723", "724", "725", "726", "727", "728", "729", "730", "731", "732", "733", "734", "735", "736", "737", "738", "739", "740", "741", "742", "743", "744", "745", "746", "747", "748", "749", "750", "751", "752", "753", "754", "755", "756", "757", "758", "759", "760", "761", "762", "763", "764", "765", "766", "767", "768", "769", "770", "771", "772", "773", "774", "775", "776", "777", "778", "779", "780", "781", "782", "783", "784", "785", "786", "787", "788", "789", "790", "791", "792", "793", "794", "795", "796", "797", "798", "799", "800", "801", "802", "803", "804", "805", "806", "807", "808", "809", "810", "811", "812", "813", "814", "815", "816", "817", "818", "819", "820", "821", "822", "823", "824", "825", "826", "827", "828", "829", "830", "831", "832", "833", "834", "835", "836", "837", "838", "839", "840", "841", "842", "843", "844", "845", "846", "847", "848", "849", "850", "851", "852", "853", "854", "855", "856", "857", "858", "859", "860", "861", "862", "863", "864", "865", "866", "867", "868", "869", "870", "871", "872", "873", "874", "875", "876", "877", "878", "879", "880", "881", "882", "883", "884", "885", "886", "887", "888", "889", "890", "891", "892", "893", "894", "895", "896", "897", "898", "899", "900", "901", "902", "903", "904", "905", "906", "907", "908", "909", "910", "911", "912", "913", "914", "915", "916", "917", "918", "919", "920", "921", "922", "923", "924", "925", "926", "927", "928", "929", "930", "931", "932", "933", "934", "935", "936", "937", "938", "939", "940", "941", "942", "943", "944", "945", "946", "947", "948", "949", "950", "951", "952", "953", "954", "955", "956", "957", "958", "959", "960", "961", "962", "963", "964", "965", "966", "967", "968", "969", "970", "971", "972", "973", "974", "975", "976", "977", "978", "979", "980", "981", "982", "983", "984", "985", "986", "987", "988", "989", "990", "991", "992", "993", "994", "995", "996", "997", "998", "999"]
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Country Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Country")
                    .font(.headline)
                
                Picker("Country", selection: $selectedCountry) {
                    ForEach(countries, id: \.0) { country in
                        Text("\(country.0) - \(country.1)")
                            .tag(country.0)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedCountry) { oldValue, newValue in
                    selectedAreaCode = ""
                    generatedNumbers = []
                    showingNumbers = false
                }
            }
            
            // Area Code Selection
            if !selectedCountry.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Area Code")
                        .font(.headline)
                    
                    Picker("Area Code", selection: $selectedAreaCode) {
                        Text("Select Area Code")
                            .tag("")
                        
                        ForEach(areaCodes[selectedCountry] ?? [], id: \.self) { areaCode in
                            Text(areaCode)
                                .tag(areaCode)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedAreaCode) { oldValue, newValue in
                        generatedNumbers = []
                        showingNumbers = false
                    }
                }
            }
            
            // Generate Button
            if !selectedAreaCode.isEmpty {
                Button("Generate Phone Numbers") {
                    generatePhoneNumbers()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedAreaCode.isEmpty)
            }
            
            // Generated Numbers
            if showingNumbers {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Generated Numbers")
                        .font(.headline)
                    
                    ForEach(generatedNumbers, id: \.self) { number in
                        HStack {
                            Text(number)
                                .font(.system(.body, design: .monospaced))
                            
                            Spacer()
                            
                            Button("Select") {
                                onSelect(number)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }
    
    private func generatePhoneNumbers() {
        generatedNumbers = []
        for _ in 0..<5 {
            let randomNumber = Int.random(in: 1000000...9999999)
            let phoneNumber = "\(selectedCountry)\(selectedAreaCode)\(randomNumber)"
            generatedNumbers.append(phoneNumber)
        }
        showingNumbers = true
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Profile Image View
struct ProfileImageView: View {
    let imageURL: String?
    let placeholderText: String
    let size: CGFloat
    
    init(imageURL: String?, placeholderText: String, size: CGFloat = 50) {
        self.imageURL = imageURL
        self.placeholderText = placeholderText
        self.size = size
    }
    
    var body: some View {
        Group {
            if let imageURL = imageURL, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderView
                }
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    private var placeholderView: some View {
        Text(placeholderText)
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .purple]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

// MARK: - Loading View
struct LoadingView: View {
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
