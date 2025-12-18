import SwiftUI
import Combine

final class ContactManager: ObservableObject {
    static let shared = ContactManager()

    @Published var contacts: [Contact] = []
    @Published var filteredContacts: [Contact] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText = ""

    private let dataPersistence = DataPersistenceManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var pollingCancellable: AnyCancellable?

    private init() {
        setupSearchObserver()
    }

    deinit {
        pollingCancellable?.cancel()
    }

    // MARK: - Contact CRUD Operations

    func loadContacts() async {
        isLoading = true
        defer { isLoading = false }

        // Load cached contacts first
        let cachedContacts = dataPersistence.getCachedContacts()
        if !cachedContacts.isEmpty {
            await MainActor.run {
                self.contacts = cachedContacts
                self.updateFilteredContacts()
            }
        }

        do {
            let loadedContacts = try await DatabaseManager.shared.fetchContacts()

            await MainActor.run {
                self.contacts = loadedContacts
                self.updateFilteredContacts()
            }

            dataPersistence.cacheContacts(loadedContacts)
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }

    func addContact(_ contact: Contact) async throws {
        if dataPersistence.isOfflineMode {
            var updatedContacts = contacts
            updatedContacts.append(contact)
            dataPersistence.cacheContacts(updatedContacts)

            await MainActor.run {
                self.contacts = updatedContacts
                self.updateFilteredContacts()
            }
            return
        }

        try await DatabaseManager.shared.addContact(
            name: contact.name,
            phone: contact.phone,
            email: contact.email
        )

        await loadContacts()
    }

    func updateContact(_ contact: Contact) async throws {
        // TODO: add an UPDATE method to `DatabaseManager` for contacts.
        await MainActor.run {
            if let index = self.contacts.firstIndex(where: { $0.id == contact.id }) {
                self.contacts[index] = contact
                self.updateFilteredContacts()
            }
        }
        dataPersistence.cacheContacts(contacts)
    }

    func deleteContact(_ contact: Contact) async throws {
        try await DatabaseManager.shared.deleteContact(contact.id)

        await MainActor.run {
            self.contacts.removeAll { $0.id == contact.id }
            self.updateFilteredContacts()
        }

        dataPersistence.cacheContacts(contacts)
    }

    // MARK: - “Real-time” Updates (polling)

    func startListeningForContacts() {
        pollingCancellable?.cancel()

        pollingCancellable = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .prepend(Date())
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.loadContacts() }
            }
    }

    func stopListeningForContacts() {
        pollingCancellable?.cancel()
        pollingCancellable = nil
    }

    // MARK: - Search and Filter

    private func setupSearchObserver() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFilteredContacts()
            }
            .store(in: &cancellables)
    }

    private func updateFilteredContacts() {
        if searchText.isEmpty {
            filteredContacts = contacts
        } else {
            filteredContacts = contacts.filter { contact in
                contact.name.localizedCaseInsensitiveContains(searchText) ||
                contact.phone.contains(searchText) ||
                contact.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Phone Number Generation

    func generatePhoneNumber(for countryCode: String) -> String {
        let areaCode = Int.random(in: 200...999)
        let randomNumber = Int.random(in: 1000000...9999999)
        return "\(countryCode)\(areaCode)\(randomNumber)"
    }

    // MARK: - Demo Data

    func loadDemoContacts() {
        contacts = Contact.sampleContacts
        updateFilteredContacts()
    }
}
