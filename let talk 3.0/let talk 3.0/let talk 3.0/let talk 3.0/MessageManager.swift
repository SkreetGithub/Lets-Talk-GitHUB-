import SwiftUI
import Combine

final class MessageManager: ObservableObject {
    static let shared = MessageManager()

    @Published var messages: [String: [Message]] = [:]
    @Published var currentChatContact: Contact?
    @Published var isTyping = false
    @Published var isLoading = false
    @Published var error: Error?

    private let dataPersistence = DataPersistenceManager.shared
    private var messageSubscriptions: [String: AnyCancellable] = [:]
    private var typingTimer: Timer?

    private init() {}

    deinit {
        stopAllListeners()
    }

    // MARK: - Message Operations

    func sendMessage(to contactId: String, text: String) async throws {
        guard let currentUserId = AuthManager.shared.currentUserId else { return }

        let message = Message(
            id: UUID().uuidString,
            senderId: currentUserId,
            receiverId: contactId,
            content: text,
            type: .text,
            timestamp: Date(),
            status: .sending
        )

        try await DatabaseManager.shared.sendMessage(message)

        await MainActor.run {
            self.messages[contactId, default: []].append(message)
            self.messages[contactId]?.sort { $0.timestamp < $1.timestamp }
        }

        dataPersistence.cacheMessages(messages[contactId] ?? [], for: contactId)

        await sendTypingIndicator(to: contactId, isTyping: false)
    }

    func sendTranslatedMessage(to contactId: String, originalText: String, translatedText: String) async throws {
        guard let currentUserId = AuthManager.shared.currentUserId else { return }

        var message = Message(
            id: UUID().uuidString,
            senderId: currentUserId,
            receiverId: contactId,
            content: translatedText,
            type: .text,
            timestamp: Date(),
            status: .sending
        )
        message.translation = originalText

        try await DatabaseManager.shared.sendMessage(message)

        await MainActor.run {
            self.messages[contactId, default: []].append(message)
            self.messages[contactId]?.sort { $0.timestamp < $1.timestamp }
        }

        dataPersistence.cacheMessages(messages[contactId] ?? [], for: contactId)
    }

    func loadMessages(for contactId: String) async {
        isLoading = true
        defer { isLoading = false }

        let cachedMessages = dataPersistence.getCachedMessages(for: contactId)
        if !cachedMessages.isEmpty {
            await MainActor.run {
                self.messages[contactId] = cachedMessages
            }
        }

        startListeningForMessages(for: contactId)
    }

    func startListeningForMessages(for contactId: String) {
        messageSubscriptions[contactId]?.cancel()

        guard let chatId = chatId(for: contactId) else { return }

        messageSubscriptions[contactId] = DatabaseManager.shared
            .listenForMessages(in: chatId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] msgs in
                    guard let self else { return }

                    // Convert messages keyed by contactId.
                    self.messages[contactId] = msgs
                    self.dataPersistence.cacheMessages(msgs, for: contactId)
                }
            )
    }

    func stopListeningForMessages(for contactId: String) {
        messageSubscriptions[contactId]?.cancel()
        messageSubscriptions[contactId] = nil
    }

    func stopAllListeners() {
        messageSubscriptions.values.forEach { $0.cancel() }
        messageSubscriptions.removeAll()
    }

    // MARK: - Typing Indicators

    func sendTypingIndicator(to contactId: String, isTyping: Bool) async {
        // TODO: implement a `typing` table + polling or Realtime.
        _ = contactId
        _ = isTyping
    }

    func startTypingIndicator(for contactId: String) {
        typingTimer?.invalidate()
        Task { await sendTypingIndicator(to: contactId, isTyping: true) }

        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { await self?.sendTypingIndicator(to: contactId, isTyping: false) }
        }
    }

    func stopTypingIndicator(for contactId: String) {
        typingTimer?.invalidate()
        Task { await sendTypingIndicator(to: contactId, isTyping: false) }
    }

    // MARK: - Message Status

    func markMessageAsRead(_ messageId: String) async {
        do {
            try await DatabaseManager.shared.markMessagesAsRead([messageId])
        } catch {
            print("Error marking message as read: \(error)")
        }
    }

    func markAllMessagesAsRead(for contactId: String) async {
        guard let currentUserId = AuthManager.shared.currentUserId else { return }

        let unreadMessages = messages[contactId]?.filter {
            $0.receiverId == currentUserId && $0.status != .read
        } ?? []

        do {
            try await DatabaseManager.shared.markMessagesAsRead(unreadMessages.map { $0.id })
        } catch {
            print("Error marking messages as read: \(error)")
        }
    }

    // MARK: - Helpers

    func getLastMessage(for contactId: String) -> String? {
        messages[contactId]?.last?.content
    }

    func getUnreadCount(for contactId: String) -> Int {
        guard let currentUserId = AuthManager.shared.currentUserId else { return 0 }
        return messages[contactId]?.filter { $0.receiverId == currentUserId && $0.status != .read }.count ?? 0
    }

    private func chatId(for contactId: String) -> String? {
        guard let currentUserId = AuthManager.shared.currentUserId else { return nil }
        let sortedIds = [currentUserId, contactId].sorted()
        return sortedIds.joined(separator: "_")
    }

    // MARK: - Demo Data

    func loadDemoMessages() {
        let demoMessages: [String: [Message]] = [
            "demo-1": [
                Message(id: "msg1", senderId: "demo-1", receiverId: "demo-user", content: "Hello! How are you?", type: .text, timestamp: Date().addingTimeInterval(-3600), status: .read),
                Message(id: "msg2", senderId: "demo-user", receiverId: "demo-1", content: "I'm doing great, thanks!", type: .text, timestamp: Date().addingTimeInterval(-1800), status: .read)
            ],
            "demo-2": [
                Message(id: "msg3", senderId: "demo-2", receiverId: "demo-user", content: "Can we schedule a call?", type: .text, timestamp: Date().addingTimeInterval(-7200), status: .delivered)
            ],
            "demo-3": [
                Message(id: "msg4", senderId: "demo-user", receiverId: "demo-3", content: "Thanks for the help!", type: .text, timestamp: Date().addingTimeInterval(-86400), status: .read)
            ]
        ]

        messages = demoMessages
    }
}

enum MessageError: Error, LocalizedError {
    case invalidData
    case sendFailed
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidData: return "Invalid message data"
        case .sendFailed: return "Failed to send message"
        case .networkError: return "Network error occurred"
        }
    }
}
