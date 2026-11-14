import SwiftUI

/// Pick a contact to start (or reopen) a conversation with.
struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var contactManager = ContactManager.shared
    @State private var searchText = ""
    @State private var openingContactId: String?
    @State private var chat: Chat?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if contactManager.contacts.isEmpty {
                    ContentUnavailableView(
                        "No Contacts Yet",
                        systemImage: "person.2",
                        description: Text("Add people in the Contacts tab (tap + there), then start a chat here.")
                    )
                } else {
                    List {
                        ForEach(visibleContacts) { contact in
                            Button {
                                open(contact)
                            } label: {
                                ContactRow(contact: contact, isOpening: openingContactId == contact.id)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(openingContactId != nil)
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search contacts")
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await contactManager.loadContacts() }
        // Closing the conversation also closes this picker and returns to the chat list.
        .fullScreenCover(item: $chat, onDismiss: { dismiss() }) { chat in
            ChatDetailView(chat: chat)
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
    
    /// The signed-in user's real contacts, filtered by the search box.
    private var visibleContacts: [Contact] {
        let list = contactManager.contacts
        guard !searchText.isEmpty else { return list }
        return list.filter { c in
            c.name.localizedCaseInsensitiveContains(searchText) ||
            c.phone.contains(searchText) ||
            c.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func open(_ contact: Contact) {
        KeyboardDismisser.dismiss()
        openingContactId = contact.id
        Task {
            do {
                let opened = try await DatabaseManager.shared.openChat(with: contact)
                await MainActor.run {
                    openingContactId = nil
                    chat = opened
                }
            } catch {
                await MainActor.run {
                    openingContactId = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    NewChatView()
}
