import SwiftUI

/// New Message: pick a contact, or type a Let Talk number / email to message anyone on Let Talk.
/// The search field is always there (it used to disappear when you had no contacts yet).
struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var contactManager = ContactManager.shared
    @State private var searchText = ""
    @State private var openingId: String?
    @State private var chat: Chat?
    @State private var errorMessage: String?
    @State private var showAddContact = false
    @FocusState private var searchFocused: Bool

    private static let typedEntryId = "typed-entry"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        Text("To:").foregroundStyle(.secondary)
                        TextField("Name, Let Talk number or email", text: $searchText)
                            .focused($searchFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.default)
                            .submitLabel(.go)
                            .onSubmit { if typedEntry != nil { openTyped() } }
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear")
                        }
                    }
                }

                if let typed = typedEntry {
                    Section {
                        Button(action: openTyped) {
                            HStack(spacing: 12) {
                                Image(systemName: typed.contains("@") ? "envelope.circle.fill" : "number.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Message \(typed)").font(.body.weight(.semibold))
                                    Text("Start a chat with this Let Talk user").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if openingId == Self.typedEntryId { ProgressView() }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(openingId != nil)
                    }
                }

                Section(contactManager.contacts.isEmpty ? "" : "Contacts") {
                    if contactManager.contacts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No contacts yet").font(.headline)
                            Text("Type someone's Let Talk number or email above, or add a contact.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button("Add Contact") { showAddContact = true }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                    } else if visibleContacts.isEmpty {
                        Text("No contacts match \"\(searchText)\"").foregroundStyle(.secondary)
                    } else {
                        ForEach(visibleContacts) { contact in
                            Button { open(contact) } label: {
                                ContactRow(contact: contact, isOpening: openingId == contact.id)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(openingId != nil)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            await contactManager.loadContacts()
            searchFocused = true
        }
        // Closing the conversation also closes this picker and returns to the chat list.
        .fullScreenCover(item: $chat, onDismiss: { dismiss() }) { chat in
            ChatDetailView(chat: chat)
        }
        .sheet(isPresented: $showAddContact) {
            AddContactView()
        }
        .alert("Can't Start Chat", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// What was typed, when it looks like a phone number (7+ digits) or an email address.
    private var typedEntry: String? {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("@"), text.contains("."), !text.contains(" ") { return text }
        let allowed = CharacterSet(charactersIn: "0123456789+-() .")
        if text.unicodeScalars.allSatisfy({ allowed.contains($0) }), text.filter(\.isNumber).count >= 7 {
            return text
        }
        return nil
    }

    /// The signed-in user's contacts, filtered by what's typed.
    private var visibleContacts: [Contact] {
        let list = contactManager.contacts
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return list }
        let digits = query.filter(\.isNumber)
        return list.filter { c in
            c.name.localizedCaseInsensitiveContains(query) ||
            c.email.localizedCaseInsensitiveContains(query) ||
            (!digits.isEmpty && c.phone.filter(\.isNumber).contains(digits))
        }
    }

    private func open(_ contact: Contact) {
        start(id: contact.id) { try await DatabaseManager.shared.openChat(with: contact) }
    }

    private func openTyped() {
        guard let typed = typedEntry else { return }
        start(id: Self.typedEntryId) { try await DatabaseManager.shared.openChat(withNumberOrEmail: typed) }
    }

    private func start(id: String, _ work: @escaping () async throws -> Chat) {
        KeyboardDismisser.dismiss()
        openingId = id
        Task {
            do {
                let opened = try await work()
                await MainActor.run { openingId = nil; chat = opened }
            } catch {
                await MainActor.run { openingId = nil; errorMessage = error.localizedDescription }
            }
        }
    }
}

#Preview {
    NewChatView()
}
