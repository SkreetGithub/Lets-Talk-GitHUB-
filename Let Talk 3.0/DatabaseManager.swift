import Foundation
import Combine
import Supabase

final class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()

    private let client = SupabaseManager.client
    private var listeners: [String: AnyCancellable] = [:]

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {}

    // MARK: - Messages

    func sendMessage(_ message: Message) async throws {
        guard AuthManager.shared.currentUserId != nil else {
            throw NSError(domain: "DatabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let chatId = getChatId(senderId: message.senderId, receiverId: message.receiverId)

        var row: [String: Any] = [
            "id": message.id,
            "chat_id": chatId,
            "sender_id": message.senderId,
            "receiver_id": message.receiverId,
            "content": message.content,
            "timestamp": ISO8601DateFormatter().string(from: message.timestamp),
            "type": message.type.rawValue,
            "status": message.status.rawValue,
            "is_encrypted": message.isEncrypted
        ]

        if let translation = message.translation {
            row["translation"] = translation
        }

        if let attachments = message.attachments,
           let encoded = try? JSONEncoder().encode(attachments),
           let json = try? JSONSerialization.jsonObject(with: encoded) {
            row["attachments"] = json
        }

        if let metadata = message.metadata {
            row["metadata"] = metadata
        }

        _ = try await client.from("messages")
            .insert(row)
            .execute()

        try await updateLastMessage(chatId: chatId, message: message)
    }

    func listenForMessages(in chatId: String) -> AnyPublisher<[Message], Error> {
        let subject = PassthroughSubject<[Message], Error>()

        // Initial load + polling (simple, works without Realtime wiring).
        let cancellable = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .prepend(Date())
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    do {
                        let messages = try await self.fetchMessages(chatId: chatId)
                        subject.send(messages)
                    } catch {
                        subject.send(completion: .failure(error))
                    }
                }
            }

        listeners["messages_\(chatId)"] = cancellable
        return subject.eraseToAnyPublisher()
    }

    private func fetchMessages(chatId: String) async throws -> [Message] {
        let response = try await client.from("messages")
            .select()
            .eq("chat_id", value: chatId)
            .order("timestamp", ascending: true)
            .limit(50)
            .execute()

        let rows = try decoder.decode([MessageRow].self, from: response.data)
        return rows.map { $0.asMessage }
    }

    // MARK: - Chats

    func createOrUpdateChat(senderId: String, receiverId: String) async throws -> Chat {
        guard !senderId.isEmpty, !receiverId.isEmpty else {
            throw NSError(domain: "DatabaseManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid sender or receiver ID"])
        }

        guard AuthManager.shared.currentUserId != nil else {
            throw NSError(domain: "DatabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let chatId = getChatId(senderId: senderId, receiverId: receiverId)

        let row: [String: Any] = [
            "id": chatId,
            "participants": [senderId, receiverId],
            "last_updated": ISO8601DateFormatter().string(from: Date())
        ]

        _ = try await client.from("chats")
            .upsert(row)
            .execute()

        return Chat(
            id: chatId,
            participants: [senderId, receiverId],
            lastMessage: nil,
            createdAt: Date(),
            lastUpdated: Date(),
            isPinned: false,
            imageURL: nil
        )
    }

    func listenForChats(userId: String) -> AnyPublisher<[Chat], Error> {
        let subject = PassthroughSubject<[Chat], Error>()

        let cancellable = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .prepend(Date())
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    do {
                        let chats = try await self.fetchChats(userId: userId)
                        subject.send(chats)
                    } catch {
                        subject.send(completion: .failure(error))
                    }
                }
            }

        listeners["chats_\(userId)"] = cancellable
        return subject.eraseToAnyPublisher()
    }

    private func fetchChats(userId: String) async throws -> [Chat] {
        // Assumes `chats.participants` is a Postgres text[] column.
        let response = try await client.from("chats")
            .select()
            .contains("participants", value: [userId])
            .execute()

        let rows = try decoder.decode([ChatRowData].self, from: response.data)
        return rows.map { $0.asChat }
    }

    // MARK: - Users

    func getUser(id: String) async throws -> User {
        let response = try await client.from("profiles")
            .select()
            .eq("id", value: id)
            .single()
            .execute()

        let profile = try decoder.decode(ProfileLookupRow.self, from: response.data)
        return profile.asUser
    }

    func searchUsers(query: String) async throws -> [User] {
        let response = try await client.from("profiles")
            .select()
            .ilike("name", pattern: "%\(query)%")
            .limit(25)
            .execute()

        let profiles = try decoder.decode([ProfileLookupRow].self, from: response.data)
        return profiles.map { $0.asUser }
    }

    // MARK: - Contacts

    func fetchContacts() async throws -> [Contact] {
        guard let userId = AuthManager.shared.currentUserId else {
            throw NSError(domain: "DatabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let response = try await client.from("contacts")
            .select()
            .eq("owner_id", value: userId)
            .order("name", ascending: true)
            .execute()

        let rows = try decoder.decode([ContactRowData].self, from: response.data)
        return rows.map { $0.asContact }
    }

    func addContact(name: String, phone: String, email: String) async throws {
        guard let userId = AuthManager.shared.currentUserId else {
            throw NSError(domain: "DatabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let row: [String: Any] = [
            "id": UUID().uuidString,
            "owner_id": userId,
            "name": name,
            "phone": phone,
            "email": email,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]

        _ = try await client.from("contacts")
            .insert(row)
            .execute()
    }

    func deleteContact(_ contactId: String) async throws {
        _ = try await client.from("contacts")
            .delete()
            .eq("id", value: contactId)
            .execute()
    }

    // MARK: - Calls

    func fetchCalls() async throws -> [CallRecord] {
        // TODO: Implement calls table in Supabase.
        return []
    }

    func deleteCall(_ callId: String) async throws {
        _ = try await client.from("calls")
            .delete()
            .eq("id", value: callId)
            .execute()
    }

    // MARK: - Chat Management

    func deleteChat(_ chatId: String) async throws {
        _ = try await client.from("chats")
            .delete()
            .eq("id", value: chatId)
            .execute()
    }

    func pinChat(_ chatId: String) async throws {
        _ = try await client.from("chats")
            .update(["is_pinned": true])
            .eq("id", value: chatId)
            .execute()
    }

    func markChatAsRead(_ chatId: String) async throws {
        _ = try await client.from("chats")
            .update(["unread_count": 0])
            .eq("id", value: chatId)
            .execute()
    }

    func markMessagesAsRead(_ messageIds: [String]) async throws {
        for messageId in messageIds {
            _ = try await client.from("messages")
                .update(["status": "read"])
                .eq("id", value: messageId)
                .execute()
        }
    }

    // MARK: - Push Token

    /// Kept for backwards compatibility: this now stores the APNs token (or any push token)
    /// on the user's Supabase profile.
    func updateFCMToken(_ token: String) async throws {
        guard let userId = AuthManager.shared.currentUserId else { return }

        // Store as a single-element array for now.
        _ = try await client.from("profiles")
            .update(["device_tokens": [token]])
            .eq("id", value: userId)
            .execute()
    }

    func removeListeners() {
        listeners.values.forEach { $0.cancel() }
        listeners.removeAll()
    }

    deinit {
        removeListeners()
    }

    // MARK: - Helpers

    private func getChatId(senderId: String, receiverId: String) -> String {
        let sortedIds = [senderId, receiverId].sorted()
        return sortedIds.joined(separator: "_")
    }

    private func updateLastMessage(chatId: String, message: Message) async throws {
        let lastMessage: [String: Any] = [
            "content": message.content,
            "sender_id": message.senderId,
            "timestamp": ISO8601DateFormatter().string(from: message.timestamp),
            "type": message.type.rawValue,
            "is_read": message.status == .read
        ]

        _ = try await client.from("chats")
            .update([
                "last_message": lastMessage,
                "last_updated": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: chatId)
            .execute()
    }
}

// MARK: - Supabase row decoding

private struct MessageRow: Codable {
    let id: String
    let senderId: String
    let receiverId: String
    let content: String
    let timestamp: Date
    let type: String
    let status: String
    let isEncrypted: Bool
    let translation: String?
    let attachments: [Message.Attachment]?
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case content
        case timestamp
        case type
        case status
        case isEncrypted = "is_encrypted"
        case translation
        case attachments
        case metadata
    }

    var asMessage: Message {
        var m = Message(
            id: id,
            senderId: senderId,
            receiverId: receiverId,
            content: content,
            type: Message.MessageType(rawValue: type) ?? .text,
            attachments: attachments,
            timestamp: timestamp,
            status: Message.MessageStatus(rawValue: status) ?? .sent,
            isEncrypted: isEncrypted
        )
        m.translation = translation
        m.metadata = metadata
        return m
    }
}

private struct ChatRowData: Codable {
    let id: String
    let participants: [String]
    let createdAt: Date?
    let lastUpdated: Date?
    let isPinned: Bool?
    let imageURL: String?
    let unreadCount: Int?
    let lastMessage: ChatLastMessageRow?

    enum CodingKeys: String, CodingKey {
        case id
        case participants
        case createdAt = "created_at"
        case lastUpdated = "last_updated"
        case isPinned = "is_pinned"
        case imageURL = "image_url"
        case unreadCount = "unread_count"
        case lastMessage = "last_message"
    }

    var asChat: Chat {
        Chat(
            id: id,
            participants: participants,
            lastMessage: lastMessage?.asLastMessage,
            createdAt: createdAt ?? Date(),
            lastUpdated: lastUpdated ?? Date(),
            isPinned: isPinned ?? false,
            imageURL: imageURL,
            unreadCount: unreadCount ?? 0
        )
    }
}

private struct ChatLastMessageRow: Codable {
    let content: String
    let senderId: String
    let timestamp: Date
    let type: String
    let isRead: Bool?

    enum CodingKeys: String, CodingKey {
        case content
        case senderId = "sender_id"
        case timestamp
        case type
        case isRead = "is_read"
    }

    var asLastMessage: Chat.LastMessage {
        Chat.LastMessage(
            content: content,
            senderId: senderId,
            timestamp: timestamp,
            type: Message.MessageType(rawValue: type) ?? .text,
            isRead: isRead ?? false
        )
    }
}

private struct ContactRowData: Codable {
    let id: String
    let name: String
    let phone: String
    let email: String
    let lastMessage: String?
    let imageURL: String?
    let lastSeen: Date?
    let isOnline: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case phone
        case email
        case lastMessage = "last_message"
        case imageURL = "image_url"
        case lastSeen = "last_seen"
        case isOnline = "is_online"
    }

    var asContact: Contact {
        var c = Contact(id: id, name: name, phone: phone, email: email, lastMessage: lastMessage)
        c.imageURL = imageURL
        c.lastSeen = lastSeen
        c.isOnline = isOnline ?? false
        return c
    }
}

private struct ProfileLookupRow: Codable {
    let id: String
    let email: String
    let name: String
    let phone: String
    let photoURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case phone
        case photoURL = "photo_url"
    }

    var asUser: User {
        User(id: id, email: email, name: name, phone: phone, photoURL: photoURL)
    }
}

struct Chat: Identifiable, Codable {
    let id: String
    let participants: [String]
    var lastMessage: LastMessage?
    let createdAt: Date
    var lastUpdated: Date
    var isPinned: Bool = false
    var imageURL: String?
    var unreadCount: Int = 0

    var title: String {
        "Chat"
    }

    var lastMessageTime: String {
        guard let lastMessage else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: lastMessage.timestamp)
    }

    struct LastMessage: Codable {
        let content: String
        let senderId: String
        let timestamp: Date
        let type: Message.MessageType
        var isRead: Bool = false
    }
}
