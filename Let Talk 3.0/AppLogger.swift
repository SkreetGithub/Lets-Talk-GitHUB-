import Foundation
import OSLog

/// Comprehensive logging utility for debugging and troubleshooting
final class AppLogger {
    static let shared = AppLogger()
    
    private let logger = Logger(subsystem: "com.lettalk.app", category: "AppLogger")
    
    private init() {}
    
    // MARK: - Log Levels
    
    enum LogLevel: String {
        case debug = "🔍 DEBUG"
        case info = "ℹ️ INFO"
        case success = "✅ SUCCESS"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"
        case database = "💾 DATABASE"
        case call = "📞 CALL"
        case message = "💬 MESSAGE"
        case auth = "🔐 AUTH"
        case storage = "📦 STORAGE"
    }
    
    // MARK: - Public Logging Methods
    
    func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(level.rawValue) [\(fileName):\(line)] \(function) - \(message)"
        
        // Print to console
        print(logMessage)
        
        // Log to system logger
        switch level {
        case .error:
            logger.error("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .debug:
            logger.debug("\(logMessage)")
        default:
            logger.info("\(logMessage)")
        }
    }
    
    // MARK: - Convenience Methods
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.success, message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
    
    // MARK: - Domain-Specific Logging
    
    func database(_ message: String, details: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if !details.isEmpty {
            let detailsStr = details.map { "\($0.key): \(String(describing: $0.value))" }.joined(separator: ", ")
            fullMessage += " | \(detailsStr)"
        }
        log(.database, fullMessage, file: file, function: function, line: line)
    }
    
    func call(_ message: String, details: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if !details.isEmpty {
            let detailsStr = details.map { "\($0.key): \(String(describing: $0.value))" }.joined(separator: ", ")
            fullMessage += " | \(detailsStr)"
        }
        log(.call, fullMessage, file: file, function: function, line: line)
    }
    
    func message(_ message: String, details: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if !details.isEmpty {
            let detailsStr = details.map { "\($0.key): \(String(describing: $0.value))" }.joined(separator: ", ")
            fullMessage += " | \(detailsStr)"
        }
        log(.message, fullMessage, file: file, function: function, line: line)
    }
    
    func auth(_ message: String, details: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if !details.isEmpty {
            let detailsStr = details.map { "\($0.key): \(String(describing: $0.value))" }.joined(separator: ", ")
            fullMessage += " | \(detailsStr)"
        }
        log(.auth, fullMessage, file: file, function: function, line: line)
    }
    
    func storage(_ message: String, details: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if !details.isEmpty {
            let detailsStr = details.map { "\($0.key): \(String(describing: $0.value))" }.joined(separator: ", ")
            fullMessage += " | \(detailsStr)"
        }
        log(.storage, fullMessage, file: file, function: function, line: line)
    }
    
    func success(_ message: String, details: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if !details.isEmpty {
            let detailsStr = details.map { "\($0.key): \(String(describing: $0.value))" }.joined(separator: ", ")
            fullMessage += " | \(detailsStr)"
        }
        log(.success, fullMessage, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, details: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if !details.isEmpty {
            let detailsStr = details.map { "\($0.key): \(String(describing: $0.value))" }.joined(separator: ", ")
            fullMessage += " | \(detailsStr)"
        }
        log(.warning, fullMessage, file: file, function: function, line: line)
    }
    
    // MARK: - Structured Logging
    
    func logDatabaseOperation(operation: String, table: String, userId: String? = nil, details: [String: Any] = [:]) {
        var message = "\(operation) on '\(table)'"
        if let userId = userId {
            message += " | UserID: \(userId)"
        }
        if !details.isEmpty {
            let detailsStr = details.map { "\($0.key): \(String(describing: $0.value))" }.joined(separator: ", ")
            message += " | \(detailsStr)"
        }
        database(message)
    }
    
    func logCallEvent(event: String, callId: String? = nil, userId: String? = nil, details: [String: Any] = [:]) {
        var message = "\(event)"
        if let callId = callId {
            message += " | CallID: \(callId)"
        }
        if let userId = userId {
            message += " | UserID: \(userId)"
        }
        if !details.isEmpty {
            let detailsStr = details.map { "\($0.key): \(String(describing: $0.value))" }.joined(separator: ", ")
            message += " | \(detailsStr)"
        }
        call(message)
    }
    
    func logMessageEvent(event: String, messageId: String? = nil, senderId: String? = nil, receiverId: String? = nil, details: [String: Any] = [:]) {
        var message = "\(event)"
        if let messageId = messageId {
            message += " | MessageID: \(messageId)"
        }
        if let senderId = senderId {
            message += " | SenderID: \(senderId)"
        }
        if let receiverId = receiverId {
            message += " | ReceiverID: \(receiverId)"
        }
        if !details.isEmpty {
            let detailsStr = details.map { "\($0.key): \(String(describing: $0.value))" }.joined(separator: ", ")
            message += " | \(detailsStr)"
        }
        self.message(message)
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

