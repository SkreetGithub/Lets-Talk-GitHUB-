import SwiftUI

struct NewChatView: View {
    @Environment(\.presentationMode) var presentationMode
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
                    ForEach(mockContacts) { contact in
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
    
    private var mockContacts: [Contact] {
        [
            Contact(name: "John Doe", phone: "123-456-7890", email: "john@example.com", lastMessage: "Hello!", image: nil),
            Contact(name: "Jane Smith", phone: "098-765-4321", email: "jane@example.com", lastMessage: "How are you?", image: nil),
            Contact(name: "Bob Johnson", phone: "555-123-4567", email: "bob@example.com", lastMessage: "See you later!", image: nil)
        ]
    }
}

// ContactRow is defined in ContactsView.swift

#Preview {
    NewChatView()
}
