import Foundation
import Combine
import Supabase

final class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()

    private let client = SupabaseManager.client
    private var listeners: [String: AnyCancellable] = [:]

    // .iso8601 rejects Supabase's fractional seconds ("...04.174123+00:00"), so rows failed to decode.
    private let decoder: JSONDecoder = PostgresDate.decoder

    private init() {}

    // MARK: - Messages

    func sendMessage(_ message: Message) async throws {
        guard AuthManager.shared.currentUserId != nil else {
            throw NSError(domain: "DatabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let chatId = getChatId(senderId: message.senderId, receiverId: message.receiverId)

        var attachmentsJSON: String? = nil
        if let attachments = message.attachments,
           let encoded = try? JSONEncoder().encode(attachments),
           let jsonString = String(data: encoded, encoding: .utf8) {
            attachmentsJSON = jsonString
        }
        
        var metadataJSON: String? = nil
        if let metadata = message.metadata,
           let encoded = try? JSONEncoder().encode(metadata),
           let jsonString = String(data: encoded, encoding: .utf8) {
            metadataJSON = jsonString
        }
        
        let row = MessageInsert(
            id: message.id,
            chatId: chatId,
            senderId: message.senderId,
            receiverId: message.receiverId,
            content: message.content,
            timestamp: ISO8601DateFormatter().string(from: message.timestamp),
            type: message.type.rawValue,
            status: message.status.rawValue,
            isEncrypted: message.isEncrypted,
            translation: message.translation,
            attachments: attachmentsJSON,
            metadata: metadataJSON
        )

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
                        // A dropped connection used to END the stream, so the chat stopped updating
                        // for good. Skip this tick; the next poll tries again.
                        debugLog("Message poll failed: \(error)")
                    }
                }
            }

        listeners["messages_\(chatId)"] = cancellable
        return subject.eraseToAnyPublisher()
    }

    private func fetchMessages(chatId: String) async throws -> [Message] {
        // The NEWEST 50 (ascending + limit returned the oldest 50, so once a chat passed 50
        // messages new ones never appeared). Reversed back into reading order.
        let response = try await client.from("messages")
            .select()
            .eq("chat_id", value: chatId)
            .order("timestamp", ascending: false)
            .limit(50)
            .execute()

        let rows = try decoder.decode([MessageRow].self, from: response.data)
        return rows.reversed().map { $0.asMessage }
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

        let row = ChatInsert(
            id: chatId,
            participants: [senderId, receiverId],
            lastUpdated: ISO8601DateFormatter().string(from: Date())
        )

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

    /// Opens (creating if needed) the 1:1 chat with a saved contact.
    /// A contact is an address-book entry, so the person's Let Talk account is found from the
    /// contact's linked user ID or, failing that, its phone number. (Chats used to be created with
    /// the contact ROW id, which is nobody's account, so messages never reached anyone.)
    func openChat(with contact: Contact) async throws -> Chat {
        guard let me = AuthManager.shared.currentUserId?.lowercased() else { throw ChatError.notSignedIn }
        var otherUserId = contact.userId?.lowercased()
        if otherUserId == nil, contact.phone.filter(\.isNumber).count >= 7 {
            otherUserId = try await findUserId(byPhone: contact.phone)?.lowercased()
        }
        guard let otherUserId else { throw ChatError.notOnLetTalk(contact.name) }
        guard otherUserId != me else { throw ChatError.ownAccount }
        return try await createOrUpdateChat(senderId: me, receiverId: otherUserId)
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
                        debugLog("Chat list poll failed: \(error)")   // retried on the next tick
                    }
                }
            }

        listeners["chats_\(userId)"] = cancellable
        return subject.eraseToAnyPublisher()
    }

    private func fetchChats(userId: String) async throws -> [Chat] {
        // Assumes `chats.participants` is a Postgres text[] column.
        // Chats I deleted stay for the other person; they're only hidden from me (hidden_for).
        let me = userId.lowercased()
        let response = try await client.from("chats")
            .select()
            .contains("participants", value: [userId])
            .not("hidden_for", operator: .cs, value: "{\(me)}")
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

    /// Finds the Let Talk user who owns a phone number, or nil if nobody does.
    /// Numbers are stored in more than one format ("4704588823" from sign-up,
    /// "(470) 458-8823" from the number picker), so every common format is tried.
    func findUserId(byPhone raw: String) async throws -> String? {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 7 else { return nil }
        let last10 = String(digits.suffix(10))
        var candidates: Set<String> = [digits, last10, "1" + last10]
        if last10.count == 10 {
            let a = last10.prefix(3), b = last10.dropFirst(3).prefix(3), c = last10.suffix(4)
            candidates.formUnion(["(\(a)) \(b)-\(c)", "\(a)-\(b)-\(c)", "\(a) \(b) \(c)"])
        }

        // PostgREST needs values containing ( ) , or spaces to be double-quoted inside in.(...),
        // and supabase-swift does not quote them, so the old query never matched "(470) 789-6062".
        // "+" variants are left out: an unescaped "+" in a query string is decoded as a space.
        let quoted = candidates.map { "\"\($0)\"" }
        let response = try await client.from("profiles")
            .select("id, phone")
            .in("phone", values: quoted)
            .limit(5)
            .execute()

        struct Row: Decodable { let id: String; let phone: String? }
        let rows = try decoder.decode([Row].self, from: response.data)
        // Prefer the row whose digits really match (guards against a short-number collision).
        return rows.first { ($0.phone ?? "").filter(\.isNumber).hasSuffix(last10) }?.id ?? rows.first?.id
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

        let row = ContactInsert(
            id: UUID().uuidString,
            ownerId: userId,
            name: name,
            phone: phone,
            email: email,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        _ = try await client.from("contacts")
            .insert(row)
            .execute()
    }

    /// Adds a Let Talk user (e.g. from a scanned QR code) as a contact, using their profile's
    /// name, phone and email. Adding the same person twice is a no-op.
    func addContact(letTalkUserId userId: String) async throws -> Contact {
        guard let ownerId = AuthManager.shared.currentUserId else { throw QRAddError.notSignedIn }

        let user: User
        do {
            user = try await getUser(id: userId)
        } catch {
            throw QRAddError.accountNotFound
        }

        let row = ContactInsert(
            id: UUID().uuidString,
            ownerId: ownerId,
            name: user.name,
            phone: user.phone,
            email: user.email,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            contactUserId: userId
        )
        // Unique (owner_id, contact_user_id): a second scan of the same code adds nothing.
        _ = try await client.from("contacts")
            .upsert(row, onConflict: "owner_id,contact_user_id", ignoreDuplicates: true)
            .execute()

        var contact = Contact(id: row.id, name: user.name, phone: user.phone, email: user.email)
        contact.userId = userId
        contact.imageURL = user.photoURL
        return contact
    }

    func deleteContact(_ contactId: String) async throws {
        _ = try await client.from("contacts")
            .delete()
            .eq("id", value: contactId)
            .execute()
    }

    // MARK: - Calls

    /// Recent calls for the Calls tab, newest first. (This used to always return an empty list,
    /// so call history never showed anything.)
    func fetchCalls() async throws -> [CallRecord] {
        guard let me = AuthManager.shared.currentUserId?.lowercased() else { return [] }

        let response = try await client.from("calls")
            .select("id, caller_id, callee_id, is_video, status, created_at, answered_at, ended_at")
            .contains("participants", value: [me])
            .not("hidden_for", operator: .cs, value: "{\(me)}")   // calls I deleted
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
        let rows = try decoder.decode([CallHistoryRow].self, from: response.data)

        // Names: saved contacts first, then the other person's profile.
        let others = Set(rows.map { $0.callerId.lowercased() == me ? $0.calleeId : $0.callerId })
        var people: [String: Contact] = [:]
        let saved = await MainActor.run { ContactManager.shared.contacts }
        for id in others {
            if let contact = saved.first(where: { $0.userId?.lowercased() == id.lowercased() }) {
                people[id] = contact
            } else if let user = try? await getUser(id: id) {
                var contact = Contact(id: id, name: user.name, phone: user.phone, email: user.email)
                contact.userId = id
                contact.imageURL = user.photoURL
                people[id] = contact
            }
        }

        return rows.map { row in
            let outgoing = row.callerId.lowercased() == me
            let otherId = outgoing ? row.calleeId : row.callerId
            var contact = people[otherId] ?? Contact(id: otherId, name: "Let Talk User", phone: "", email: "")
            contact.userId = otherId
            let duration: Int
            if let answered = row.answeredAt, let ended = row.endedAt {
                duration = max(0, Int(ended.timeIntervalSince(answered)))
            } else {
                duration = 0
            }
            let neverAnswered = row.answeredAt == nil && row.status != "initiated" && row.status != "ringing"
            return CallRecord(
                id: row.id,
                contact: contact,
                type: row.isVideo ? .video : .audio,
                timestamp: row.createdAt,
                duration: duration,
                isMissed: !outgoing && (row.status == "missed" || neverAnswered),
                direction: outgoing ? .outgoing : .incoming
            )
        }
    }

    /// Removes a call from MY history only; the other person still sees it.
    /// (This used to delete the row for both people.)
    func deleteCall(_ callId: String) async throws {
        _ = try await client.rpc("hide_call", params: ["p_call_id": callId]).execute()
    }

    // MARK: - Chat Management

    /// Removes a chat from MY list only; the other person keeps it. A new message in the chat
    /// brings it back. (This used to delete the chat for both people.)
    func deleteChat(_ chatId: String) async throws {
        _ = try await client.rpc("hide_chat", params: ["p_chat_id": chatId]).execute()
    }

    func pinChat(_ chatId: String) async throws {
        try await setChatPinned(chatId, pinned: true)
    }

    /// Pins or unpins a chat (unpin used to be impossible: the button always pinned).
    func setChatPinned(_ chatId: String, pinned: Bool) async throws {
        _ = try await client.from("chats")
            .update(["is_pinned": pinned])
            .eq("id", value: chatId)
            .execute()
    }

    func markChatAsRead(_ chatId: String) async throws {
        _ = try await client.from("chats")
            .update(["unread_count": 0])
            .eq("id", value: chatId)
            .execute()
    }

    /// Read receipts. Only the receiver can mark a message read, and only `read_at`/`status`
    /// change (enforced on the server). The old direct update was always rejected: the
    /// database only let the SENDER update a message, so nothing was ever marked read.
    func markMessageRead(_ messageId: String) async throws {
        _ = try await client.rpc("mark_message_read", params: ["p_message_id": messageId]).execute()
    }

    func markMessagesAsRead(_ messageIds: [String]) async throws {
        guard !messageIds.isEmpty else { return }
        if messageIds.count == 1 {
            try await markMessageRead(messageIds[0])
        } else {
            _ = try await client.rpc("mark_messages_read", params: ["p_message_ids": messageIds]).execute()
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
        let lastMessage = ChatLastMessageUpdate(
            content: message.content,
            senderId: message.senderId,
            timestamp: ISO8601DateFormatter().string(from: message.timestamp),
            type: message.type.rawValue,
            isRead: message.status == .read
        )
        
        let updateData = ChatUpdate(
            lastMessage: lastMessage,
            lastUpdated: ISO8601DateFormatter().string(from: Date()),
            hiddenFor: []   // a new message brings a deleted chat back for both people
        )

        _ = try await client.from("chats")
            .update(updateData)
            .eq("id", value: chatId)
            .execute()
    }
}

// MARK: - Supabase Insert/Update Structs

private struct MessageInsert: Codable {
    let id: String
    let chatId: String
    let senderId: String
    let receiverId: String
    let content: String
    let timestamp: String
    let type: String
    let status: String
    let isEncrypted: Bool
    let translation: String?
    let attachments: String?
    let metadata: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
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
}

private struct ChatInsert: Codable {
    let id: String
    let participants: [String]
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case participants
        case lastUpdated = "last_updated"
    }
}

private struct ChatUpdate: Codable {
    let lastMessage: ChatLastMessageUpdate?
    let lastUpdated: String
    let hiddenFor: [String]
    
    enum CodingKeys: String, CodingKey {
        case lastMessage = "last_message"
        case lastUpdated = "last_updated"
        case hiddenFor = "hidden_for"
    }
}

private struct ChatLastMessageUpdate: Codable {
    let content: String
    let senderId: String
    let timestamp: String
    let type: String
    let isRead: Bool
    
    enum CodingKeys: String, CodingKey {
        case content
        case senderId = "sender_id"
        case timestamp
        case type
        case isRead = "is_read"
    }
}

private struct ContactInsert: Codable {
    let id: String
    let ownerId: String
    let name: String
    let phone: String
    let email: String
    let createdAt: String
    /// Set only when the contact is a known Let Talk user (omitted from the JSON when nil).
    var contactUserId: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case phone
        case email
        case createdAt = "created_at"
        case contactUserId = "contact_user_id"
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
    let readAt: Date?

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
        case readAt = "read_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        senderId = try container.decode(String.self, forKey: .senderId)
        receiverId = try container.decode(String.self, forKey: .receiverId)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        type = try container.decode(String.self, forKey: .type)
        status = try container.decode(String.self, forKey: .status)
        isEncrypted = try container.decode(Bool.self, forKey: .isEncrypted)
        translation = try container.decodeIfPresent(String.self, forKey: .translation)
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
        
        // Decode attachments from JSON string if present
        if let attachmentsString = try? container.decodeIfPresent(String.self, forKey: .attachments),
           let data = attachmentsString.data(using: .utf8) {
            attachments = try? JSONDecoder().decode([Message.Attachment].self, from: data)
        } else {
            attachments = try? container.decodeIfPresent([Message.Attachment].self, forKey: .attachments)
        }
        
        // Decode metadata from JSON string if present
        if let metadataString = try? container.decodeIfPresent(String.self, forKey: .metadata),
           let data = metadataString.data(using: .utf8) {
            metadata = try? JSONDecoder().decode([String: String].self, from: data)
        } else {
            metadata = try? container.decodeIfPresent([String: String].self, forKey: .metadata)
        }
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
            status: readAt != nil ? .read : (Message.MessageStatus(rawValue: status) ?? .sent),
            isEncrypted: isEncrypted
        )
        m.translation = translation
        m.metadata = metadata
        m.readAt = readAt
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

private struct CallHistoryRow: Decodable {
    let id: String
    let callerId: String
    let calleeId: String
    let isVideo: Bool
    let status: String
    let createdAt: Date
    let answeredAt: Date?
    let endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case callerId = "caller_id"
        case calleeId = "callee_id"
        case isVideo = "is_video"
        case status
        case createdAt = "created_at"
        case answeredAt = "answered_at"
        case endedAt = "ended_at"
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
    let contactUserId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case phone
        case email
        case contactUserId = "contact_user_id"
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
        c.userId = contactUserId
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

/// Why a chat couldn't be opened, in words the user can act on.
enum ChatError: LocalizedError {
    case notSignedIn
    case notOnLetTalk(String)
    case ownAccount

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Please sign in again to send messages."
        case .notOnLetTalk(let name):
            let who = name.isEmpty ? "This contact" : name
            return "\(who) isn't on Let Talk yet. Invite them from their contact card so you can chat."
        case .ownAccount:
            return "That's your own account. Pick someone else to chat with."
        }
    }
}
