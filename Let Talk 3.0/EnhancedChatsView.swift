import SwiftUI

struct EnhancedChatsView: View {
    @Binding var showNewChat: Bool
    @EnvironmentObject var settingsManager: SettingsManager
    @StateObject private var contactManager = ContactManager.shared
    @State private var searchText = ""
    @State private var selectedContact: Contact?
    @State private var showMessageView = false
    
    var body: some View {
        VStack {
            Text("Enhanced Chats View")
                .font(.largeTitle)
                .padding()
            
            Text("\(contactManager.contacts.count) conversations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
            
            Button("New Chat") {
                showNewChat = true
            }
            .padding()
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showNewChat) {
            NewChatView()
        }
        .sheet(isPresented: $showMessageView) {
            if let contact = selectedContact {
                EnhancedMessageView(contact: contact)
            }
        }
        .onAppear {
            Task {
                await contactManager.loadContacts()
            }
        }
    }
}

#Preview {
    EnhancedChatsView(showNewChat: .constant(false))
        .environmentObject(SettingsManager.shared)
}