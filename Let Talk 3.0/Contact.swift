import SwiftUI

struct Contact: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let phone: String
    let email: String
    let lastMessage: String?
    var image: UIImage?
    var imageURL: String?
    var lastSeen: Date?
    var isOnline: Bool = false
    
    var initials: String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Contact, rhs: Contact) -> Bool {
        lhs.id == rhs.id
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, name, phone, email, lastMessage, imageURL, lastSeen, isOnline
    }
    
    init(id: String = UUID().uuidString, name: String, phone: String, email: String, lastMessage: String? = nil, image: UIImage? = nil) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.lastMessage = lastMessage
        self.image = image
        self.lastSeen = Date()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        phone = try container.decode(String.self, forKey: .phone)
        email = try container.decode(String.self, forKey: .email)
        lastMessage = try container.decodeIfPresent(String.self, forKey: .lastMessage)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        lastSeen = try container.decodeIfPresent(Date.self, forKey: .lastSeen)
        isOnline = try container.decodeIfPresent(Bool.self, forKey: .isOnline) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(phone, forKey: .phone)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(lastMessage, forKey: .lastMessage)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(lastSeen, forKey: .lastSeen)
        try container.encode(isOnline, forKey: .isOnline)
    }
    
    // Sample contacts for preview and testing
    static var sampleContacts: [Contact] = [
        Contact(name: "John Doe", phone: "(555) 123-4567", email: "john@example.com", lastMessage: "Hey, how are you?"),
        Contact(name: "Jane Smith", phone: "(555) 987-6543", email: "jane@example.com", lastMessage: "Can we meet tomorrow?"),
        Contact(name: "Alex Johnson", phone: "(555) 456-7890", email: "alex@example.com", lastMessage: "Thanks for your help!"),
        Contact(name: "Sarah Wilson", phone: "(555) 234-5678", email: "sarah@example.com", lastMessage: "See you soon!"),
        Contact(name: "Mike Brown", phone: "(555) 876-5432", email: "mike@example.com", lastMessage: "Great work!")
    ]
}
