import SwiftUI
import Contacts
import Combine

struct ContactsView: View {
    @StateObject private var viewModel = ContactsViewModel()
    @State private var searchText = ""
    @State private var showAddContact = false
    @State private var selectedContact: Contact?
    @State private var showContactActions = false
    @State private var showCallView = false
    @State private var callContact: Contact?
    @State private var isVideoCall = false
    @State private var showChatView = false
    @State private var selectedChat: Chat?
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.contacts.isEmpty {
                EmptyContactsView(showAddContact: $showAddContact)
            } else {
                contactsList
            }
        }
        .searchable(text: $searchText, prompt: "Search contacts")
        .navigationBarItems(trailing: Button(action: { showAddContact = true }) {
            Image(systemName: "person.badge.plus")
        })
        .sheet(isPresented: $showAddContact) {
            AddContactView()
        }
        .sheet(item: $selectedContact) { contact in
            ContactDetailsView(contact: contact)
        }
        .refreshable {
            await viewModel.refreshContacts()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred")
        }
        .fullScreenCover(isPresented: $showCallView) {
            if let contact = callContact {
                CallView(contact: contact, isVideo: isVideoCall)
            }
        }
        .fullScreenCover(isPresented: $showChatView) {
            if let chat = selectedChat {
                ChatDetailView(chat: chat)
            }
        }
    }
    
    private var contactsList: some View {
        List {
            ForEach(groupedContacts.keys.sorted(), id: \.self) { key in
                Section(header: Text(key)) {
                    ForEach(groupedContacts[key] ?? []) { contact in
                        ContactRow(contact: contact)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedContact = contact
                            }
                            .contextMenu {
                                contactContextMenu(for: contact)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteContact(contact)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    viewModel.startChat(with: contact) { chat in
                                        if let chat = chat {
                                            selectedChat = chat
                                            showChatView = true
                                        }
                                    }
                                } label: {
                                    Label("Message", systemImage: "message")
                                }
                                .tint(.blue)
                                
                                Button {
                                    callContact = contact
                                    isVideoCall = false
                                    showCallView = true
                                } label: {
                                    Label("Call", systemImage: "phone")
                                }
                                .tint(.green)
                                
                                Button {
                                    callContact = contact
                                    isVideoCall = true
                                    showCallView = true
                                } label: {
                                    Label("Video", systemImage: "video")
                                }
                                .tint(.purple)
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var groupedContacts: [String: [Contact]] {
        Dictionary(grouping: filteredContacts) { contact in
            String(contact.name.prefix(1).uppercased())
        }
    }
    
    private var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return viewModel.contacts
        } else {
            return viewModel.contacts.filter { contact in
                contact.name.localizedCaseInsensitiveContains(searchText) ||
                contact.phone.localizedCaseInsensitiveContains(searchText) ||
                contact.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    @ViewBuilder
    private func contactContextMenu(for contact: Contact) -> some View {
        Button {
            viewModel.startChat(with: contact) { chat in
                if let chat = chat {
                    selectedChat = chat
                    showChatView = true
                }
            }
        } label: {
            Label("Message", systemImage: "message")
        }
        
        Button {
            callContact = contact
            isVideoCall = false
            showCallView = true
        } label: {
            Label("Call", systemImage: "phone")
        }
        
        Button {
            callContact = contact
            isVideoCall = true
            showCallView = true
        } label: {
            Label("Video Call", systemImage: "video")
        }
        
        Button {
            UIPasteboard.general.string = contact.phone
        } label: {
            Label("Copy Phone", systemImage: "doc.on.doc")
        }
        
        Button(role: .destructive) {
            viewModel.deleteContact(contact)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

struct ContactRow: View {
    let contact: Contact
    
    var body: some View {
        HStack(spacing: 12) {
            ProfileImageView(imageURL: nil,
                           placeholderText: contact.initials)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(contact.phone)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if contact.isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyContactsView: View {
    @Binding var showAddContact: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Contacts")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add contacts to start messaging")
                .foregroundColor(.gray)
            
            Button(action: { showAddContact = true }) {
                Text("Add Contact")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
    }
}

class ContactsViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showError = false
    
    private let contactManager = ContactManager.shared
    private let webRTCService = WebRTCService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupContactManager()
        loadContacts()
    }
    
    private func setupContactManager() {
        // Subscribe to ContactManager updates
        contactManager.$contacts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contacts in
                self?.contacts = contacts
            }
            .store(in: &cancellables)
        
        contactManager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &cancellables)
        
        contactManager.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.error = error
                self?.showError = error != nil
            }
            .store(in: &cancellables)
    }
    
    func loadContacts() {
        Task {
            await contactManager.loadContacts()
        }
    }
    
    func refreshContacts() async {
        await contactManager.loadContacts()
    }
    
    func deleteContact(_ contact: Contact) {
        Task {
            do {
                try await contactManager.deleteContact(contact)
            } catch {
                await MainActor.run {
                    self.error = error
                    self.showError = true
                }
            }
        }
    }
    
    func startChat(with contact: Contact, completion: @escaping (Chat?) -> Void = { _ in }) {
        Task {
            do {
                // Check if user is authenticated
                guard let currentUserId = AuthManager.shared.currentUserId, !currentUserId.isEmpty else {
                    print("Error: User not authenticated or user ID is empty")
                    await MainActor.run {
                        self.error = NSError(domain: "ContactsView", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                        self.showError = true
                        completion(nil)
                    }
                    return
                }
                
                print("Starting chat with contact: \(contact.name), User ID: \(currentUserId)")
                
                let chat = try await DatabaseManager.shared.createOrUpdateChat(
                    senderId: currentUserId,
                    receiverId: contact.id
                )
                await MainActor.run {
                    completion(chat)
                }
            } catch {
                print("Error creating chat: \(error)")
                await MainActor.run {
                    self.error = error
                    self.showError = true
                    completion(nil)
                }
            }
        }
    }
    
    func startCall(with contact: Contact) {
        Task {
            do {
                try await webRTCService.startCall(to: contact.phone)
            } catch {
                await MainActor.run {
                    self.error = error
                    self.showError = true
                }
            }
        }
    }
    
    func startVideoCall(with contact: Contact) {
        Task {
            do {
                try await webRTCService.startVideoCall(to: contact.phone)
            } catch {
                await MainActor.run {
                    self.error = error
                    self.showError = true
                }
            }
        }
    }
}

// MARK: - Enhanced Add Contact View
struct AddContactView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var selectedCountryCode = "+1"
    @State private var showPhoneGenerator = false
    @State private var generatedPhone = ""
    @StateObject private var viewModel = AddContactViewModel()
    
    private let countryCodes = ["+1", "+44", "+33", "+49", "+39", "+34", "+81", "+86", "+91"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Contact Information") {
                    TextField("Name", text: $name)
                    
                    HStack {
                        Picker("Country", selection: $selectedCountryCode) {
                            ForEach(countryCodes, id: \.self) { code in
                                Text(code).tag(code)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 80)
                        
                        TextField("Phone Number", text: $phone)
                            .keyboardType(.phonePad)
                    }
                    
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                }
                
                Section("Phone Number Generator") {
                    Button("Generate Unique Phone Number") {
                        generatePhoneNumber()
                    }
                    .foregroundColor(.blue)
                    
                    if !generatedPhone.isEmpty {
                        HStack {
                            Text("Generated:")
                            Spacer()
                            Text(generatedPhone)
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                            
                            Button("Use") {
                                phone = generatedPhone
                                generatedPhone = ""
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    let finalPhone = phone.hasPrefix("+") ? phone : "\(selectedCountryCode)\(phone)"
                    viewModel.addContact(name: name, phone: finalPhone, email: email)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(name.isEmpty || phone.isEmpty)
            )
        }
    }
    
    private func generatePhoneNumber() {
        generatedPhone = ContactManager.shared.generatePhoneNumber(for: selectedCountryCode)
    }
}

class AddContactViewModel: ObservableObject {
    private let contactManager = ContactManager.shared
    
    func addContact(name: String, phone: String, email: String) {
        Task {
            do {
                let contact = Contact(name: name, phone: phone, email: email)
                try await contactManager.addContact(contact)
            } catch {
                // Handle error
                print("Error adding contact: \(error)")
            }
        }
    }
}

struct ContactDetailsView: View {
    let contact: Contact
    @Environment(\.presentationMode) var presentationMode
    @State private var showCallOptions = false
    @State private var showCopyAlert = false
    @State private var showCallView = false
    @State private var isVideoCall = false
    @State private var showChatView = false
    @State private var selectedChat: Chat?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Profile Section
                VStack(spacing: 16) {
                    ProfileImageView(imageURL: contact.imageURL, placeholderText: contact.initials)
                        .frame(width: 120, height: 120)
                    
                    Text(contact.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(contact.phone)
                        .font(.headline)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            copyPhoneNumber()
                        }
                    
                    Text(contact.email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Call Button
                    Button(action: { showCallOptions = true }) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Call")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    
                    // Message Button
                    Button(action: { startChat() }) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Message")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Contact Details")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .actionSheet(isPresented: $showCallOptions) {
            ActionSheet(title: Text("Call Options"), buttons: [
                .default(Text("Audio Call")) { 
                    isVideoCall = false
                    showCallView = true
                },
                .default(Text("Video Call")) { 
                    isVideoCall = true
                    showCallView = true
                },
                .cancel()
            ])
        }
        .fullScreenCover(isPresented: $showCallView) {
            CallView(contact: contact, isVideo: isVideoCall)
        }
        .alert("Number Copied", isPresented: $showCopyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Phone number copied to clipboard")
        }
    }
    
    private func copyPhoneNumber() {
        UIPasteboard.general.string = contact.phone
        showCopyAlert = true
    }
    
    private func startAudioCall() {
        Task {
            do {
                try await WebRTCService.shared.startCall(to: contact.phone, isVideo: false)
            } catch {
                print("Error starting audio call: \(error)")
            }
        }
    }
    
    private func startVideoCall() {
        Task {
            do {
                try await WebRTCService.shared.startVideoCall(to: contact.phone)
            } catch {
                print("Error starting video call: \(error)")
            }
        }
    }
    
    private func startChat() {
        Task {
            do {
                // Create or get existing chat with the contact
                let chat = try await DatabaseManager.shared.createOrUpdateChat(
                    senderId: AuthManager.shared.currentUserId ?? "",
                    receiverId: contact.id
                )
                
                await MainActor.run {
                    self.selectedChat = chat
                    self.showChatView = true
                }
            } catch {
                print("Error creating chat: \(error)")
            }
        }
    }
}

struct ContactsView_Previews: PreviewProvider {
    static var previews: some View {
        ContactsView()
    }
}
