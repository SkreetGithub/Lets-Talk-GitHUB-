import Foundation
import Combine
import UIKit

// MARK: - Data Models

struct CachedContact: Codable {
    let id: String
    let name: String
    let phone: String
    let email: String
    let lastMessage: String?
    let isOnline: Bool
    let lastSeen: Date?
    let cachedAt: Date

    init(from contact: Contact) {
        self.id = contact.id
        self.name = contact.name
        self.phone = contact.phone
        self.email = contact.email
        self.lastMessage = contact.lastMessage
        self.isOnline = contact.isOnline
        self.lastSeen = contact.lastSeen
        self.cachedAt = Date()
    }

    func toContact() -> Contact {
        var contact = Contact(id: id, name: name, phone: phone, email: email, lastMessage: lastMessage)
        contact.image = nil
        contact.imageURL = nil
        contact.lastSeen = lastSeen
        contact.isOnline = isOnline
        return contact
    }
}

struct CachedMessage: Codable {
    let id: String
    let senderId: String
    let receiverId: String
    let content: String
    let timestamp: Date
    let type: String
    let status: String
    let translation: String?
    let isEncrypted: Bool
    let cachedAt: Date

    init(from message: Message) {
        self.id = message.id
        self.senderId = message.senderId
        self.receiverId = message.receiverId
        self.content = message.content
        self.timestamp = message.timestamp
        self.type = message.type.rawValue
        self.status = message.status.rawValue
        self.translation = message.translation
        self.isEncrypted = message.isEncrypted
        self.cachedAt = Date()
    }

    func toMessage() -> Message {
        var message = Message(
            id: id,
            senderId: senderId,
            receiverId: receiverId,
            content: content,
            type: Message.MessageType(rawValue: type) ?? .text,
            attachments: nil,
            timestamp: timestamp,
            status: Message.MessageStatus(rawValue: status) ?? .sent,
            isEncrypted: isEncrypted
        )
        message.translation = translation
        return message
    }
}

struct CachedCall: Codable {
    let id: String
    let callerId: String
    let receiverId: String
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let isVideo: Bool
    let status: String
    let cachedAt: Date

    init(id: String, callerId: String, receiverId: String, startTime: Date, endTime: Date? = nil, duration: TimeInterval, isVideo: Bool, status: String) {
        self.id = id
        self.callerId = callerId
        self.receiverId = receiverId
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.isVideo = isVideo
        self.status = status
        self.cachedAt = Date()
    }
}

struct CachedTranslation: Codable {
    let id: String
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date
    let cachedAt: Date

    init(id: String, originalText: String, translatedText: String, sourceLanguage: String, targetLanguage: String, timestamp: Date) {
        self.id = id
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
        self.cachedAt = Date()
    }
}

// MARK: - Data Persistence Manager

final class DataPersistenceManager: ObservableObject {
    static let shared = DataPersistenceManager()

    private let userDefaults = UserDefaults.standard

    // Cache keys
    private enum CacheKeys {
        static let contacts = "cached_contacts"
        static let messages = "cached_messages"
        static let calls = "cached_calls"
        static let translations = "cached_translations"
        static let lastSyncTime = "last_sync_time"
        static let offlineMode = "offline_mode"
    }

    // Cache expiration times (in seconds)
    private enum CacheExpiration {
        static let contacts: TimeInterval = 3600
        static let messages: TimeInterval = 86400
        static let calls: TimeInterval = 604800
        static let translations: TimeInterval = 2592000
    }

    @Published var isOfflineMode = false
    @Published var lastSyncTime: Date?
    @Published var syncInProgress = false

    private init() {
        loadOfflineMode()
        loadLastSyncTime()
    }

    // MARK: - Contacts Caching

    func cacheContacts(_ contacts: [Contact]) {
        let cached = contacts.map { CachedContact(from: $0) }
        do {
            let data = try JSONEncoder().encode(cached)
            userDefaults.set(data, forKey: CacheKeys.contacts)
        } catch {
            print("❌ Failed to cache contacts: \(error)")
        }
    }

    func getCachedContacts() -> [Contact] {
        guard let data = userDefaults.data(forKey: CacheKeys.contacts) else { return [] }

        do {
            let cached = try JSONDecoder().decode([CachedContact].self, from: data)
            let valid = cached.filter { Date().timeIntervalSince($0.cachedAt) < CacheExpiration.contacts }

            if valid.count != cached.count {
                cacheContacts(valid.map { $0.toContact() })
            }

            return valid.map { $0.toContact() }
        } catch {
            print("❌ Failed to load cached contacts: \(error)")
            return []
        }
    }

    // MARK: - Messages Caching

    func cacheMessages(_ messages: [Message], for contactId: String) {
        let cached = messages.map { CachedMessage(from: $0) }
        do {
            let data = try JSONEncoder().encode(cached)
            userDefaults.set(data, forKey: "\(CacheKeys.messages)_\(contactId)")
        } catch {
            print("❌ Failed to cache messages: \(error)")
        }
    }

    func getCachedMessages(for contactId: String) -> [Message] {
        let key = "\(CacheKeys.messages)_\(contactId)"
        guard let data = userDefaults.data(forKey: key) else { return [] }

        do {
            let cached = try JSONDecoder().decode([CachedMessage].self, from: data)
            let valid = cached.filter { Date().timeIntervalSince($0.cachedAt) < CacheExpiration.messages }

            if valid.count != cached.count {
                cacheMessages(valid.map { $0.toMessage() }, for: contactId)
            }

            return valid.map { $0.toMessage() }
        } catch {
            print("❌ Failed to load cached messages: \(error)")
            return []
        }
    }

    // MARK: - Calls Caching

    func cacheCall(_ call: CachedCall) {
        var cachedCalls = getCachedCalls()
        cachedCalls.append(call)

        if cachedCalls.count > 100 {
            cachedCalls = Array(cachedCalls.suffix(100))
        }

        do {
            let data = try JSONEncoder().encode(cachedCalls)
            userDefaults.set(data, forKey: CacheKeys.calls)
        } catch {
            print("❌ Failed to cache call: \(error)")
        }
    }

    func getCachedCalls() -> [CachedCall] {
        guard let data = userDefaults.data(forKey: CacheKeys.calls) else { return [] }

        do {
            let cached = try JSONDecoder().decode([CachedCall].self, from: data)
            let valid = cached.filter { Date().timeIntervalSince($0.cachedAt) < CacheExpiration.calls }

            if valid.count != cached.count {
                let data = try JSONEncoder().encode(valid)
                userDefaults.set(data, forKey: CacheKeys.calls)
            }

            return valid.sorted { $0.startTime > $1.startTime }
        } catch {
            print("❌ Failed to load cached calls: \(error)")
            return []
        }
    }

    // MARK: - Translations Caching

    func cacheTranslation(_ translation: CachedTranslation) {
        var cached = getCachedTranslations()
        cached.append(translation)

        if cached.count > 500 {
            cached = Array(cached.suffix(500))
        }

        do {
            let data = try JSONEncoder().encode(cached)
            userDefaults.set(data, forKey: CacheKeys.translations)
        } catch {
            print("❌ Failed to cache translation: \(error)")
        }
    }

    func getCachedTranslations() -> [CachedTranslation] {
        guard let data = userDefaults.data(forKey: CacheKeys.translations) else { return [] }

        do {
            let cached = try JSONDecoder().decode([CachedTranslation].self, from: data)
            let valid = cached.filter { Date().timeIntervalSince($0.cachedAt) < CacheExpiration.translations }

            if valid.count != cached.count {
                let data = try JSONEncoder().encode(valid)
                userDefaults.set(data, forKey: CacheKeys.translations)
            }

            return valid.sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("❌ Failed to load cached translations: \(error)")
            return []
        }
    }

    // MARK: - Sync Management

    /// Backwards-compatible name: Firebase has been removed; this now syncs from Supabase.
    func syncWithFirebase() async {
        await syncWithBackend()
    }

    func syncWithBackend() async {
        guard !syncInProgress else { return }
        guard !isOfflineMode else { return }
        guard AuthManager.shared.currentUserId != nil else { return }

        syncInProgress = true
        defer { syncInProgress = false }

        do {
            let contacts = try await DatabaseManager.shared.fetchContacts()
            cacheContacts(contacts)

            lastSyncTime = Date()
            saveLastSyncTime()
        } catch {
            print("❌ Sync failed: \(error)")
        }
    }

    // MARK: - Offline Mode

    func enableOfflineMode() {
        isOfflineMode = true
        saveOfflineMode(true)
    }

    func disableOfflineMode() {
        isOfflineMode = false
        saveOfflineMode(false)
    }

    private func saveOfflineMode(_ isOffline: Bool) {
        userDefaults.set(isOffline, forKey: CacheKeys.offlineMode)
    }

    private func loadOfflineMode() {
        isOfflineMode = userDefaults.bool(forKey: CacheKeys.offlineMode)
    }

    private func saveLastSyncTime() {
        if let syncTime = lastSyncTime {
            userDefaults.set(syncTime, forKey: CacheKeys.lastSyncTime)
        }
    }

    private func loadLastSyncTime() {
        lastSyncTime = userDefaults.object(forKey: CacheKeys.lastSyncTime) as? Date
    }

    // MARK: - Cache Management

    func clearAllCache() {
        userDefaults.removeObject(forKey: CacheKeys.contacts)
        userDefaults.removeObject(forKey: CacheKeys.calls)
        userDefaults.removeObject(forKey: CacheKeys.translations)
        userDefaults.removeObject(forKey: CacheKeys.lastSyncTime)
    }

    func clearExpiredCache() {
        _ = getCachedContacts()
        _ = getCachedCalls()
        _ = getCachedTranslations()
    }

    // MARK: - Background Sync

    func scheduleBackgroundSync() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.syncWithBackend() }
        }
    }
}
