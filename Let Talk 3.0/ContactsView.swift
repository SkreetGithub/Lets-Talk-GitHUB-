import SwiftUI
import Contacts
import Combine

struct ContactsView: View {
    @StateObject private var viewModel = ContactsViewModel()
    @State private var searchText = ""
    @State private var showAddContact = false
    @State private var selectedContact: Contact?
    @State private var selectedChat: Chat?
    
    var body: some View {
        // Own navigation bar (like Chats) so the search field sits at the top under the title.
        // On the shared outer bar, iOS 26 put it at the bottom, over the tab bar.
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.contacts.isEmpty {
                    EmptyContactsView(showAddContact: $showAddContact)
                } else {
                    contactsList
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddContact = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Add contact")
                }
            }
        }
        .sheet(isPresented: $showAddContact) {
            AddContactView()
        }
        .sheet(item: $selectedContact) { contact in
            ContactDetailsView(contact: contact)
        }
        .logoRefreshable {
            await viewModel.refreshContacts()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred")
        }
        // `item:` (not isPresented + if-let) so the chat screen always gets its chat.
        .fullScreenCover(item: $selectedChat) { chat in
            ChatDetailView(chat: chat)
        }
    }
    
    /// Tapping a contact opens your conversation with them (like Messages / WhatsApp).
    private func openChat(with contact: Contact) {
        KeyboardDismisser.dismiss()
        viewModel.startChat(with: contact) { chat in
            if let chat { selectedChat = chat }
        }
    }
    
    private var contactsList: some View {
        List {
            ForEach(groupedContacts.keys.sorted(), id: \.self) { key in
                Section(header: Text(key)) {
                    ForEach(groupedContacts[key] ?? []) { contact in
                        ContactRow(contact: contact, isOpening: viewModel.openingContactId == contact.id)
                            .contentShape(Rectangle())
                            .tapGlow {
                                openChat(with: contact)
                            }
                            // Long-press for call, video, details and delete. (Row swipe actions were
                            // removed: horizontal swipes now switch between the main tabs.)
                            .contextMenu {
                                contactContextMenu(for: contact)
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, DS.floatingTabBarClearance, for: .scrollContent)
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
            openChat(with: contact)
        } label: {
            Label("Message", systemImage: "message")
        }
        
        Button {
            selectedContact = contact
        } label: {
            Label("View Contact", systemImage: "person.crop.circle")
        }
        
        Button {
            CallCoordinator.shared.startCall(to: contact, isVideo: false)
        } label: {
            Label("Call", systemImage: "phone")
        }
        
        Button {
            CallCoordinator.shared.startCall(to: contact, isVideo: true)
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
    var isOpening: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            UserAvatar(userId: contact.userId, name: contact.name,
                       fallbackURL: contact.imageURL, size: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(contact.phone)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isOpening {
                ProgressView()
            } else if contact.isOnline {
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
        EmptyStateView(
            icon: "person.2",
            title: "No Contacts",
            message: "Add contacts to start messaging.",
            actionTitle: "Add Contact",
            action: { showAddContact = true }
        )
    }
}

class ContactsViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showError = false
    /// The contact whose chat is being opened (shows a spinner on that row).
    @Published var openingContactId: String?
    
    private let contactManager = ContactManager.shared
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
        guard openingContactId == nil else { return }   // ignore double taps
        openingContactId = contact.id
        Task {
            do {
                let chat = try await DatabaseManager.shared.openChat(with: contact)
                await MainActor.run {
                    self.openingContactId = nil
                    completion(chat)
                }
            } catch {
                debugLog("Error opening chat: \(error)")
                await MainActor.run {
                    self.openingContactId = nil
                    self.error = error
                    self.showError = true
                    completion(nil)
                }
            }
        }
    }
    
    func startCall(with contact: Contact) {
        Task { @MainActor in CallCoordinator.shared.startCall(to: contact, isVideo: false) }
    }
    
    func startVideoCall(with contact: Contact) {
        Task { @MainActor in CallCoordinator.shared.startCall(to: contact, isVideo: true) }
    }
}

// MARK: - Enhanced Add Contact View
struct AddContactView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var selectedCountryCode = "+1"
    @State private var showQRScanner = false
    @State private var showContactSync = false
    @StateObject private var viewModel = AddContactViewModel()
    
    private let countryCodes = ["+1", "+44", "+33", "+49", "+39", "+34", "+81", "+86", "+91"]
    
    var body: some View {
        NavigationView {
            Form {
                // Three ways to add someone, biggest first.
                Section {
                    Button { showQRScanner = true } label: {
                        addOption(icon: "qrcode.viewfinder", color: .blue, title: "Scan QR Code",
                                  detail: "Adds their photo, Let Talk number and email in one step")
                    }
                    Button { showContactSync = true } label: {
                        addOption(icon: "person.crop.circle.badge.plus", color: .green, title: "From My iPhone Contacts",
                                  detail: "See which of your contacts use Let Talk, add them with one tap")
                    }
                } footer: {
                    Text("Your own QR code is in Settings → My QR Code.")
                }

                Section("Or Enter Manually") {
                    TextField("Name", text: $name)
                        .textContentType(.name)

                    HStack {
                        Picker("Country", selection: $selectedCountryCode) {
                            ForEach(countryCodes, id: \.self) { code in
                                Text(code).tag(code)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                        .frame(width: 80)

                        TextField("Let Talk Number", text: $phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }

                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Add Contact")
            .sheet(isPresented: $showContactSync) {
                ContactSyncView()
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { _ in
                    // Contact saved; the Contacts list refreshes itself. Close Add Contact too.
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Group {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            let finalPhone = phone.hasPrefix("+") ? phone : "\(selectedCountryCode)\(phone)"
                            viewModel.addContact(name: name.trimmingCharacters(in: .whitespaces),
                                                 phone: finalPhone,
                                                 email: email.trimmingCharacters(in: .whitespaces)) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || phone.filter(\.isNumber).count < 7)
                    }
                }
            )
            .alert("Couldn't Save Contact", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

extension AddContactView {
    fileprivate func addOption(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(color))
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).font(.headline).foregroundStyle(.primary)
                Text(LocalizedStringKey(detail)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

class AddContactViewModel: ObservableObject {
    private let contactManager = ContactManager.shared
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    /// Saves the contact, then calls `onSaved`. Errors are shown instead of silently dropping the contact.
    func addContact(name: String, phone: String, email: String, onSaved: @escaping () -> Void) {
        isSaving = true
        Task {
            do {
                let contact = Contact(name: name, phone: phone, email: email)
                try await contactManager.addContact(contact)
                await MainActor.run {
                    self.isSaving = false
                    onSaved()
                }
            } catch {
                debugLog("Error adding contact: \(error)")
                await MainActor.run {
                    self.isSaving = false
                    self.errorMessage = "Check your connection and try again."
                }
            }
        }
    }
}

struct ContactDetailsView: View {
    let contact: Contact
    @Environment(\.presentationMode) var presentationMode
    @State private var showCallOptions = false
    @State private var showCopyAlert = false
    @State private var selectedChat: Chat?
    @State private var isOpeningChat = false
    @State private var chatError: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Profile Section
                VStack(spacing: 16) {
                    UserAvatar(userId: contact.userId, name: contact.name,
                               fallbackURL: contact.imageURL, size: 120)
                    
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
                            if isOpeningChat {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "message.fill")
                            }
                            Text("Message")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isOpeningChat)
                    
                    // Invite (for contacts who aren't on Let Talk yet)
                    if contact.userId == nil {
                        ShareLink(item: LetTalkInvite.message(from: AuthManager.shared.currentUser?.name)) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Invite to Let Talk")
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(12)
                        }
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
                .default(Text("Audio Call")) { callFromDetails(isVideo: false) },
                .default(Text("Video Call")) { callFromDetails(isVideo: true) },
                .cancel()
            ])
        }
        .alert("Number Copied", isPresented: $showCopyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Phone number copied to clipboard")
        }
        .alert("Can't Open Chat", isPresented: Binding(
            get: { chatError != nil },
            set: { if !$0 { chatError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(chatError ?? "")
        }
        // The Message button used to set a flag nothing listened to, so it did nothing.
        .fullScreenCover(item: $selectedChat) { chat in
            ChatDetailView(chat: chat)
        }
    }
    
    private func copyPhoneNumber() {
        UIPasteboard.general.string = contact.phone
        showCopyAlert = true
    }
    
    private func startAudioCall() {
        callFromDetails(isVideo: false)
    }
    
    private func startVideoCall() {
        callFromDetails(isVideo: true)
    }
    
    /// Closes this sheet, then starts the call (the call screen opens in its own window).
    private func callFromDetails(isVideo: Bool) {
        presentationMode.wrappedValue.dismiss()
        let contact = contact
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)   // let the sheet finish closing
            CallCoordinator.shared.startCall(to: contact, isVideo: isVideo)
        }
    }
    
    private func startChat() {
        guard !isOpeningChat else { return }
        isOpeningChat = true
        Task {
            do {
                let chat = try await DatabaseManager.shared.openChat(with: contact)
                await MainActor.run {
                    isOpeningChat = false
                    selectedChat = chat
                }
            } catch {
                debugLog("Error creating chat: \(error)")
                await MainActor.run {
                    isOpeningChat = false
                    chatError = error.localizedDescription
                }
            }
        }
    }
}

struct ContactsView_Previews: PreviewProvider {
    static var previews: some View {
        ContactsView()
    }
}
