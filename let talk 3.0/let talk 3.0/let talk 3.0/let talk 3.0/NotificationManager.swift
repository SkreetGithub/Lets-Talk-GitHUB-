import SwiftUI
import UserNotifications
import ActivityKit

typealias ActivityID = String

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var currentMessage: (String, String, String?)? // (message, sender, profileImage)
    @Published var currentCall: CallAttributes.ContentState?
    @Published var showMessageNotification = false
    @Published var showCallNotification = false
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount = 0
    
    private var activities: [ActivityID: Activity<CallAttributes>] = [:]
    private var notificationQueue: [AppNotification] = []
    
    override init() {
        super.init()
        setupNotifications()
        loadNotifications()
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
    }

    /// Hook called by `AppDelegate` after APNs registration.
    /// (Firebase/FCM has been removed; if you need remote push, implement your own
    /// server-side push provider and store this token in Supabase.)
    @MainActor
    func didRegisterForRemoteNotifications(token: String) async {
        UserDefaults.standard.set(token, forKey: "apnsToken")
        // Optional: upload token to backend once Supabase profile storage is migrated.
    }
    
    func showMessageNotification(message: String, senderName: String, profileImage: String? = nil) {
        currentMessage = (message, senderName, profileImage)
        showMessageNotification = true
        
        // Hide notification after delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            self.showMessageNotification = false
        }
    }
    
    func showCallNotification(caller: String, isVideo: Bool, callerId: String, callerImage: String?) {
        let callState = CallAttributes.ContentState(
            callerName: caller,
            callerImage: callerImage,
            isVideoCall: isVideo,
            callState: .incoming
        )
        
        currentCall = callState
        showCallNotification = true
        
        // Start Live Activity for call
        startCallActivity(caller: caller, isVideo: isVideo, callerId: callerId, callerImage: callerImage)
    }
    
    func startCallActivity(caller: String, isVideo: Bool, callerId: String, callerImage: String?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let initialState = CallAttributes.ContentState(
            callerName: caller,
            callerImage: callerImage,
            isVideoCall: isVideo,
            callState: .incoming
        )
        
        let attributes = CallAttributes()
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: initialState,
                pushType: .token
            )
            
            activities[activity.id] = activity
            
            // Listen for activity updates
            Task {
                for await state in activity.contentStateUpdates {
                    await updateCallActivity(id: activity.id, state: state)
                }
            }
        } catch {
            print("Error starting call activity: \(error)")
        }
    }
    
    func updateCallActivity(id: ActivityID, state: CallAttributes.ContentState) async {
        guard let activity = activities[id] else { return }
        
        do {
            await activity.update(using: state)
            
            if state.callState == .ended {
                await activity.end(dismissalPolicy: .immediate)
                activities.removeValue(forKey: id)
            }
        } catch {
            print("Error updating call activity: \(error)")
        }
    }
    
    func endCallActivity(id: ActivityID) {
        guard let activity = activities[id] else { return }
        
        Task {
            await activity.end(dismissalPolicy: .immediate)
            activities.removeValue(forKey: id)
        }
    }
    
    // MARK: - In-App Notifications
    func showNotification(_ notification: AppNotification) {
        Task { @MainActor in
            self.notifications.insert(notification, at: 0)
            self.updateUnreadCount()
            self.saveNotifications()
            
            // Auto-remove after delay
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            self.removeNotification(notification.id)
        }
    }
    
    func showSuccessNotification(title: String, message: String) {
        let notification = AppNotification(
            id: UUID().uuidString,
            type: .success,
            title: title,
            message: message,
            timestamp: Date(),
            isRead: false
        )
        showNotification(notification)
    }
    
    func showErrorNotification(title: String, message: String) {
        let notification = AppNotification(
            id: UUID().uuidString,
            type: .error,
            title: title,
            message: message,
            timestamp: Date(),
            isRead: false
        )
        showNotification(notification)
    }
    
    func showInfoNotification(title: String, message: String) {
        let notification = AppNotification(
            id: UUID().uuidString,
            type: .info,
            title: title,
            message: message,
            timestamp: Date(),
            isRead: false
        )
        showNotification(notification)
    }
    
    func showCallNotification(title: String, message: String) {
        let notification = AppNotification(
            id: UUID().uuidString,
            type: .call,
            title: title,
            message: message,
            timestamp: Date(),
            isRead: false
        )
        showNotification(notification)
    }
    
    func removeNotification(_ id: String) {
        notifications.removeAll { $0.id == id }
        updateUnreadCount()
        saveNotifications()
    }
    
    func markAsRead(_ id: String) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
            updateUnreadCount()
            saveNotifications()
        }
    }
    
    func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        updateUnreadCount()
        saveNotifications()
    }
    
    func clearAllNotifications() {
        notifications.removeAll()
        updateUnreadCount()
        saveNotifications()
    }
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    // MARK: - Persistence
    private func saveNotifications() {
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: "appNotifications")
        }
    }
    
    private func loadNotifications() {
        if let data = UserDefaults.standard.data(forKey: "appNotifications"),
           let loadedNotifications = try? JSONDecoder().decode([AppNotification].self, from: data) {
            notifications = loadedNotifications
            updateUnreadCount()
        }
    }
    
    // MARK: - Push Notification Helpers
    func scheduleLocalNotification(title: String, body: String, userInfo: [String: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        if let messageData = userInfo["message"] as? [String: Any],
           let content = messageData["content"] as? String,
           let sender = messageData["sender"] as? String {
            showMessageNotification(
                message: content,
                senderName: sender,
                profileImage: messageData["profileImage"] as? String
            )
        } else if let callData = userInfo["call"] as? [String: Any],
                  let caller = callData["caller"] as? String,
                  let isVideo = callData["isVideo"] as? Bool,
                  let callerId = callData["callerId"] as? String {
            showCallNotification(
                caller: caller,
                isVideo: isVideo,
                callerId: callerId,
                callerImage: callData["callerImage"] as? String
            )
        }
        
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let messageData = userInfo["message"] as? [String: Any],
           let chatId = messageData["chatId"] as? String {
            // Handle message notification tap
            NotificationCenter.default.post(
                name: .openChat,
                object: nil,
                userInfo: ["chatId": chatId]
            )
        } else if let callData = userInfo["call"] as? [String: Any],
                  let callerId = callData["callerId"] as? String,
                  let isVideo = callData["isVideo"] as? Bool {
            // Handle call notification tap
            NotificationCenter.default.post(
                name: .handleCall,
                object: nil,
                userInfo: [
                    "callerId": callerId,
                    "isVideo": isVideo
                ]
            )
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let openChat = Notification.Name("openChat")
    static let handleCall = Notification.Name("handleCall")
}

// MARK: - Live Activity Attributes
struct CallAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var callerName: String
        var callerImage: String?
        var isVideoCall: Bool
        var callState: CallState
        
        enum CallState: String, Codable {
            case incoming
            case outgoing
            case connected
            case ended
        }
    }
}

// MARK: - View Extension for Notification Overlay
extension View {
    func notificationOverlay(manager: NotificationManager) -> some View {
        self.modifier(NotificationOverlay(notificationManager: manager))
    }
}

struct NotificationOverlay: ViewModifier {
    @ObservedObject var notificationManager: NotificationManager
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if notificationManager.showMessageNotification,
               let message = notificationManager.currentMessage {
                MessageNotificationView(
                    message: message.0,
                    senderName: message.1,
                    profileImage: message.2
                )
                .transition(.move(edge: .top))
                .zIndex(1)
            }
            
            if notificationManager.showCallNotification,
               let call = notificationManager.currentCall {
                CallNotificationView(
                    callerName: call.callerName,
                    isVideo: call.isVideoCall,
                    callerImage: call.callerImage
                )
                .transition(.move(edge: .top))
                .zIndex(2)
            }
        }
        .animation(.spring(), value: notificationManager.showMessageNotification)
        .animation(.spring(), value: notificationManager.showCallNotification)
    }
}

struct MessageNotificationView: View {
    let message: String
    let senderName: String
    let profileImage: String?
    
    var body: some View {
        HStack(spacing: 12) {
            ProfileImageView(
                imageURL: profileImage,
                placeholderText: String(senderName.prefix(2))
            )
            .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(senderName)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding()
    }
}

struct CallNotificationView: View {
    let callerName: String
    let isVideo: Bool
    let callerImage: String?
    
    var body: some View {
        HStack(spacing: 12) {
            ProfileImageView(
                imageURL: callerImage,
                placeholderText: String(callerName.prefix(2))
            )
            .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(callerName)
                    .font(.headline)
                Text("\(isVideo ? "Video" : "Audio") Call")
                    .font(.subheadline)
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: {
                    // Decline call
                }) {
                    Image(systemName: "phone.down.fill")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                
                Button(action: {
                    // Accept call
                }) {
                    Image(systemName: isVideo ? "video.fill" : "phone.fill")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.green)
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding()
    }
}
