import SwiftUI
import Contacts
import CryptoKit
import MessageUI

// MARK: - Phone hashing

/// Phone numbers leave the phone only as SHA-256 hashes. Both sides normalize the same way:
/// digits only, last 10 digits (so "+1 (470) 789-6062" and "4707896062" match). The server
/// computes the same hash of each profile's phone (profiles.phone_hash).
enum PhoneHash {
    static func normalize(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 7 else { return nil }
        return String(digits.suffix(10))
    }

    static func hash(_ raw: String) -> String? {
        guard let normalized = normalize(raw) else { return nil }
        return SHA256.hash(data: Data(normalized.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Model

@MainActor
final class ContactSyncModel: ObservableObject {
    struct Person: Identifiable {
        let id: String              // CNContact identifier
        let name: String
        let phones: [String]        // as written in the address book
        var match: Backend.ContactMatch?
    }

    enum State: Equatable {
        case idle, needsPermission, denied, loading, loaded, failed(String)
    }

    @Published var state: State = .idle
    @Published var onLetTalk: [Person] = []
    @Published var notOnLetTalk: [Person] = []
    @Published var adding = Set<String>()
    @Published var added = Set<String>()        // Let Talk user IDs added this session
    @Published var errorMessage: String?

    private let store = CNContactStore()

    func start() async {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            state = .needsPermission
        case .denied, .restricted:
            state = .denied
        default:            // .authorized, and .limited (iOS 18: only the contacts the user shared)
            await load()
        }
    }

    func requestAccess() async {
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        if granted { await load() } else { state = .denied }
    }

    func load() async {
        state = .loading
        do {
            let people = try await Task.detached(priority: .userInitiated) { () throws -> [Person] in
                let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey,
                            CNContactPhoneNumbersKey] as [CNKeyDescriptor]
                var result: [Person] = []
                try CNContactStore().enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { contact, _ in
                    let phones = contact.phoneNumbers.map(\.value.stringValue)
                    guard !phones.isEmpty else { return }
                    let full = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                    let name = full.isEmpty ? (contact.organizationName.isEmpty ? phones[0] : contact.organizationName) : full
                    result.append(Person(id: contact.identifier, name: name, phones: phones, match: nil))
                }
                return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }.value

            // Only hashes are sent; the address book itself never leaves the phone.
            var hashToPeople: [String: [Int]] = [:]
            for (index, person) in people.enumerated() {
                for phone in person.phones {
                    if let hash = PhoneHash.hash(phone) { hashToPeople[hash, default: []].append(index) }
                }
            }
            var matched = people
            let hashes = Array(hashToPeople.keys)
            for start in stride(from: 0, to: hashes.count, by: 500) {
                let chunk = Array(hashes[start..<min(start + 500, hashes.count)])
                let matches = try await Backend.matchContacts(hashes: chunk)
                for match in matches {
                    for index in hashToPeople[match.hash] ?? [] where matched[index].match == nil {
                        matched[index].match = match
                    }
                }
            }

            let me = AuthManager.shared.currentUserId?.lowercased()
            onLetTalk = matched.filter { $0.match != nil && $0.match?.userId.lowercased() != me }
            notOnLetTalk = matched.filter { $0.match == nil }
            state = .loaded
        } catch {
            state = .failed("Couldn't check your contacts. Check your connection and try again.")
        }
    }

    func isSaved(_ person: Person) -> Bool {
        guard let userId = person.match?.userId.lowercased() else { return false }
        return added.contains(userId)
            || ContactManager.shared.contacts.contains { $0.userId?.lowercased() == userId }
    }

    func add(_ person: Person) async {
        guard let userId = person.match?.userId.lowercased(), !adding.contains(userId) else { return }
        errorMessage = nil
        adding.insert(userId)
        defer { adding.remove(userId) }
        do {
            _ = try await ContactManager.shared.addContact(letTalkUserId: userId)
            added.insert(userId)
            Haptics.success()
        } catch {
            errorMessage = "Couldn't add \(person.name). Please try again."
            Haptics.failure()
        }
    }
}

// MARK: - Screen

/// Contacts → Add Contact → Find Friends from Contacts.
/// Shows which address-book contacts use Let Talk (one tap to add) and lets you invite the rest.
struct ContactSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = ContactSyncModel()
    @ObservedObject private var contactManager = ContactManager.shared
    @State private var inviteTarget: ContactSyncModel.Person?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Find Friends")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .task { await model.start() }
                .sheet(item: $inviteTarget) { person in
                    InviteComposer(person: person)
                        .ignoresSafeArea()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView("Checking your contacts…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .needsPermission:
            ContentUnavailableView {
                Label("Find Friends on Let Talk", systemImage: "person.2.circle")
            } description: {
                Text("See which of your contacts already use Let Talk. Phone numbers are checked as one-way hashes; your address book isn't uploaded or stored.")
            } actions: {
                Button("Continue") { Task { await model.requestAccess() } }
                    .buttonStyle(.borderedProminent)
            }
        case .denied:
            ContentUnavailableView {
                Label("Contacts Access Off", systemImage: "person.crop.circle.badge.xmark")
            } description: {
                Text("Turn on Contacts for Let Talk in Settings to find friends who use it.")
            } actions: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open Settings") { UIApplication.shared.open(url) }
                }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await model.load() } }
            }
        case .loaded:
            list
        }
    }

    private func filtered(_ people: [ContactSyncModel.Person]) -> [ContactSyncModel.Person] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return people }
        return people.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var list: some View {
        List {
            if let error = model.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            Section {
                if model.onLetTalk.isEmpty {
                    Text("None of your contacts are on Let Talk yet. Invite them below.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered(model.onLetTalk)) { person in
                        onLetTalkRow(person)
                    }
                }
            } header: {
                Text("On Let Talk (\(model.onLetTalk.count))")
            }

            if !model.notOnLetTalk.isEmpty {
                Section("Invite to Let Talk") {
                    ForEach(filtered(model.notOnLetTalk)) { person in
                        inviteRow(person)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search")
        .refreshable { await model.load() }
    }

    private func onLetTalkRow(_ person: ContactSyncModel.Person) -> some View {
        let userId = person.match?.userId.lowercased() ?? ""
        return HStack(spacing: DS.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.spacingXS) {
                    Text(person.name).font(.body)
                    LetTalkBadge()
                }
                if let appName = person.match?.name, !appName.isEmpty, appName != person.name {
                    Text(appName).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if model.isSaved(person) {
                Label("Added", systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } else if model.adding.contains(userId) {
                ProgressView()
            } else {
                Button("Add") { Task { await model.add(person) } }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .accessibilityLabel("Add \(person.name)")
            }
        }
        .frame(minHeight: DS.minTapTarget)
    }

    private func inviteRow(_ person: ContactSyncModel.Person) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                Text(person.phones.first ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Invite") { inviteTarget = person }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .accessibilityLabel("Invite \(person.name)")
        }
        .frame(minHeight: DS.minTapTarget)
    }
}

/// The "Let Talk" badge shown next to contacts who use the app.
struct LetTalkBadge: View {
    var body: some View {
        Text("Let Talk")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.accentColor))
            .accessibilityLabel("On Let Talk")
    }
}

// MARK: - Invite

enum LetTalkInvite {
    /// Set to the App Store link once the app has a listing (e.g. https://apps.apple.com/app/id123456789).
    static let appLink: String? = nil

    static func message(from myName: String?) -> String {
        var text = "Let's talk on Let Talk! It translates our calls and messages live, so we can each speak our own language."
        if let appLink { text += " Get it here: \(appLink)" }
        if let myName, !myName.isEmpty { text += " – \(myName)" }
        return text
    }
}

/// SMS composer with the invite pre-filled. Falls back to the share sheet where the device
/// can't send texts (e.g. the Simulator, or an iPad without Messages).
struct InviteComposer: UIViewControllerRepresentable {
    let person: ContactSyncModel.Person
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIViewController {
        let body = LetTalkInvite.message(from: AuthManager.shared.currentUser?.name)
        if MFMessageComposeViewController.canSendText() {
            let composer = MFMessageComposeViewController()
            composer.recipients = person.phones.isEmpty ? nil : [person.phones[0]]
            composer.body = body
            composer.messageComposeDelegate = context.coordinator
            return composer
        }
        let share = UIActivityViewController(activityItems: [body], applicationActivities: nil)
        share.completionWithItemsHandler = { _, _, _, _ in context.coordinator.finish() }
        return share
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }

        func finish() { dismiss() }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            dismiss()
        }
    }
}
