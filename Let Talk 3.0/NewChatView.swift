import SwiftUI

struct NewChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var contactManager = ContactManager.shared
    @State private var searchText = ""
    @State private var selectedContacts: Set<Contact> = []
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search contacts...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal)
                
                // Contact list
                List {
                    ForEach(visibleContacts) { contact in
                        ContactRow(contact: contact)
                            .onTapGesture {
                                if selectedContacts.contains(contact) {
                                    selectedContacts.remove(contact)
                                } else {
                                    selectedContacts.insert(contact)
                                }
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("New Chat")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Create") {
                    // Create chat logic
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(selectedContacts.isEmpty)
            )
        }
    }
    
    /// The signed-in user's real contacts, filtered by the search box.
    private var visibleContacts: [Contact] {
        var list = contactManager.contacts
        #if DEBUG
        if list.isEmpty { list = Self.previewContacts }
        #endif
        guard !searchText.isEmpty else { return list }
        return list.filter { c in
            c.name.localizedCaseInsensitiveContains(searchText) ||
            c.phone.contains(searchText) ||
            c.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    #if DEBUG
    private static let previewContacts: [Contact] = [
        Contact(name: "John Doe", phone: "123-456-7890", email: "john@example.com", lastMessage: "Hello!", image: nil),
        Contact(name: "Jane Smith", phone: "098-765-4321", email: "jane@example.com", lastMessage: "How are you?", image: nil)
    ]
    #endif
}

// ContactRow is defined in ContactsView.swift

#Preview {
    NewChatView()
}
