import SwiftUI

/// Friendly messages for the server's Let Talk number rules
/// (supabase_migration_v9_number_rules.sql): unique numbers, one change a year.
enum NumberRules {
    static func isTaken(_ error: Error) -> Bool {
        let text = String(describing: error)
        return text.contains("23505") || text.contains("profiles_number_unique") || text.contains("duplicate key")
    }

    static func isTooSoon(_ error: Error) -> Bool {
        String(describing: error).contains("NUMBER_CHANGE_LIMIT")
    }

    static func message(for error: Error) -> String {
        let text = String(describing: error)
        if isTaken(error) {
            return "Someone just took that number. Here are new ones to pick from."
        }
        if isTooSoon(error) {
            if let range = text.range(of: #"NUMBER_CHANGE_LIMIT:(\d{4}-\d{2}-\d{2})"#, options: .regularExpression) {
                let raw = String(text[range]).replacingOccurrences(of: "NUMBER_CHANGE_LIMIT:", with: "")
                let parser = DateFormatter()
                parser.dateFormat = "yyyy-MM-dd"
                if let date = parser.date(from: raw) {
                    return "You can change your number once a year. Your next change is available on \(date.formatted(date: .long, time: .omitted))."
                }
            }
            return "You can change your number once a year."
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return "Check your internet connection and try again."
        }
        return "Couldn't save your number. Please try again."
    }
}

/// Settings / Profile › My Let Talk Number: your number, your QR code, and Change Number
/// (once a year). This replaces the old number generator that sat in Add Contact.
struct MyNumberView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var lastChanged: Date?
    @State private var nextChange: Date?
    @State private var loaded = false
    @State private var showChange = false
    @State private var copied = false

    private var number: String { authManager.currentUser?.phone ?? "" }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                    Text(number.isEmpty ? "No number yet" : number)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .textSelection(.enabled)
                    Text("People call and message you on this number in Let Talk.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                if !number.isEmpty {
                    Button {
                        UIPasteboard.general.string = number
                        copied = true
                        Haptics.tap()
                    } label: {
                        Label(copied ? "Copied" : "Copy Number", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    ShareLink(item: "Call or message me on Let Talk: \(number)") {
                        Label("Share My Number", systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section {
                Button {
                    showChange = true
                } label: {
                    Label("Change Number", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!loaded || nextChange != nil)
            } footer: {
                if let nextChange {
                    Text("You can change your number once a year. Your next change is available on \(nextChange.formatted(date: .long, time: .omitted)).")
                } else if let lastChanged {
                    Text("Last changed \(lastChanged.formatted(date: .long, time: .omitted)). You can change your number once a year.")
                } else {
                    Text("You can change your number once a year.")
                }
            }
        }
        .navigationTitle("My Let Talk Number")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .fullScreenCover(isPresented: $showChange, onDismiss: { Task { await refresh() } }) {
            PhoneVerificationView(isPresented: $showChange, isLoggedIn: .constant(true), isChangingNumber: true)
                .environmentObject(authManager)
        }
    }

    private func refresh() async {
        let dates = await authManager.numberChangeDates()
        await MainActor.run {
            lastChanged = dates.lastChanged
            nextChange = dates.nextChange
            loaded = true
        }
    }
}
