import SwiftUI
import Foundation

// MARK: - App Notification Model
struct AppNotification: Identifiable, Codable {
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool
    
    enum NotificationType: String, Codable, CaseIterable {
        case success = "success"
        case error = "error"
        case info = "info"
        case call = "call"
        case message = "message"
        
        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.circle.fill"
            case .info:
                return "info.circle.fill"
            case .call:
                return "phone.fill"
            case .message:
                return "message.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success:
                return .green
            case .error:
                return .red
            case .info:
                return .blue
            case .call:
                return .orange
            case .message:
                return .purple
            }
        }
    }
}

// MARK: - In-App Notification View
struct InAppNotificationView: View {
    let notification: AppNotification
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.type.icon)
                .foregroundColor(notification.type.color)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding(.horizontal)
    }
}

// MARK: - Notification List View
struct NotificationListView: View {
    @ObservedObject var notificationManager: NotificationManager
    @State private var showingClearAlert = false
    
    var body: some View {
        NavigationView {
            List {
                if notificationManager.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No Notifications")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(notificationManager.notifications) { notification in
                        NotificationRowView(notification: notification) {
                            notificationManager.markAsRead(notification.id)
                        }
                        .listRowBackground(notification.isRead ? Color.clear : Color.blue.opacity(0.1))
                    }
                    .onDelete(perform: deleteNotifications)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Mark All as Read") {
                            notificationManager.markAllAsRead()
                        }
                        .disabled(notificationManager.notifications.allSatisfy { $0.isRead })
                        
                        Button("Clear All", role: .destructive) {
                            showingClearAlert = true
                        }
                        .disabled(notificationManager.notifications.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Clear All Notifications", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    notificationManager.clearAllNotifications()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    private func deleteNotifications(offsets: IndexSet) {
        for index in offsets {
            let notification = notificationManager.notifications[index]
            notificationManager.removeNotification(notification.id)
        }
    }
}

// MARK: - Notification Row View
struct NotificationRowView: View {
    let notification: AppNotification
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.type.icon)
                .foregroundColor(notification.type.color)
                .font(.title3)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(notification.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
