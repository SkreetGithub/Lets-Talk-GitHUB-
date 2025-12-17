import Foundation
import SwiftUI

struct Message: Identifiable, Codable, Hashable {
    let id: String
    let senderId: String
    let receiverId: String
    let content: String
    let timestamp: Date
    let type: MessageType
    var status: MessageStatus
    var translation: String?
    var attachments: [Attachment]?
    var isEncrypted: Bool
    var metadata: [String: String]?
    
    enum MessageType: String, Codable {
        case text
        case image
        case video
        case audio
        case file
        case location
        case contact
        case system
    }
    
    enum MessageStatus: String, Codable {
        case sending
        case sent
        case delivered
        case read
        case failed
    }
    
    struct Attachment: Codable, Hashable {
        let id: String
        let url: String
        let type: AttachmentType
        let size: Int
        let name: String
        var localPath: String?
        var thumbnailUrl: String?
        
        enum AttachmentType: String, Codable {
            case image
            case video
            case audio
            case document
        }
    }
    
    init(id: String = UUID().uuidString,
         senderId: String,
         receiverId: String,
         content: String,
         type: MessageType = .text,
         attachments: [Attachment]? = nil,
         timestamp: Date = Date(),
         status: MessageStatus = .sending,
         isEncrypted: Bool = true) {
        self.id = id
        self.senderId = senderId
        self.receiverId = receiverId
        self.content = content
        self.type = type
        self.attachments = attachments
        self.timestamp = timestamp
        self.status = status
        self.isEncrypted = isEncrypted
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
    
    // Helper computed properties
    var isOutgoing: Bool {
        senderId == AuthManager.shared.currentUserId
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(timestamp) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: timestamp)
        }
    }
    
    // Sample messages for preview
    static var sampleMessages: [Message] = [
        Message(senderId: "user1", receiverId: "user2", content: "Hey, how are you?"),
        Message(senderId: "user2", receiverId: "user1", content: "I'm good, thanks! How about you?", status: .read),
        Message(senderId: "user1", receiverId: "user2", content: "Doing great! Want to catch up later?"),
        Message(senderId: "user2", receiverId: "user1", content: "Sure, that sounds good!", status: .delivered)
    ]
}

// MARK: - Message Encryption Extension
extension Message {
    func encrypt() -> Message {
        // Implement message encryption
        var encryptedMessage = self
        // Add encryption logic here
        return encryptedMessage
    }
    
    func decrypt() -> Message {
        // Implement message decryption
        var decryptedMessage = self
        // Add decryption logic here
        return decryptedMessage
    }
}

// MARK: - Message Validation Extension
extension Message {
    func isValid() -> Bool {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        switch type {
        case .text:
            return content.count <= 2000 // Maximum text length
        case .image, .video:
            return attachments?.first != nil
        case .audio:
            return attachments?.first?.type == .audio
        case .file:
            return attachments?.first != nil && (attachments?.first?.size ?? 0) <= 100 * 1024 * 1024 // 100MB limit
        case .location:
            return content.contains(",") // Basic location format validation
        case .contact:
            return !content.isEmpty
        case .system:
            return true
        }
    }
}
