import SwiftUI
import Combine

struct ComprehensiveChatsView: View {
    @Binding var showNewChat: Bool
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ComprehensiveChatsViewModel()
    @State private var searchText = ""
    @State private var selectedChat: Chat?
    @State private var showChatDetail = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView("Loading chats...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.chats.isEmpty {
                    EmptyChatsView(showNewChat: $showNewChat)
                } else {
                    chatsList
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search conversations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showNewChat) {
            NewChatView()
        }
        .sheet(isPresented: $showSettings) {
            ComprehensiveSettingsView()
        }
        .sheet(item: $selectedChat) { chat in
            ChatDetailView(chat: chat)
        }
        .refreshable {
            await viewModel.refreshChats()
        }
        .onAppear {
            viewModel.loadChats()
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                viewModel.loadChats()
            } else {
                viewModel.clearChats()
            }
        }
    }
    
    private var chatsList: some View {
        List {
            ForEach(filteredChats) { chat in
                ChatRow(chat: chat, settingsManager: settingsManager)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedChat = chat
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteChat(chat)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            viewModel.togglePin(chat)
                        } label: {
                            Label(chat.isPinned ? "Unpin" : "Pin", 
                                  systemImage: chat.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            viewModel.markAsRead(chat)
                        } label: {
                            Label("Mark Read", systemImage: "checkmark.circle")
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.plain)
    }
    
    private var filteredChats: [Chat] {
        let sortedChats = viewModel.chats.sorted { chat1, chat2 in
            // Pinned chats first
            if chat1.isPinned != chat2.isPinned {
                return chat1.isPinned
            }
            // Then by last updated
            return chat1.lastUpdated > chat2.lastUpdated
        }
        
        if searchText.isEmpty {
            return sortedChats
        } else {
            return sortedChats.filter { chat in
                chat.title.localizedCaseInsensitiveContains(searchText) ||
                chat.lastMessage?.content.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
}

struct ChatRow: View {
    let chat: Chat
    let settingsManager: SettingsManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            ProfileImageView(
                imageURL: chat.imageURL,
                placeholderText: chat.title.prefix(1).uppercased()
            )
            .frame(width: 50, height: 50)
            .overlay(
                // Unread indicator
                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text("\(chat.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .opacity(chat.unreadCount > 0 ? 1 : 0),
                alignment: .topTrailing
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Text(chat.lastMessageTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    if let lastMessage = chat.lastMessage {
                        Text(lastMessage.content)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("No messages yet")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    Spacer()
                    
                    if chat.unreadCount > 0 {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyChatsView: View {
    @Binding var showNewChat: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "message.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Conversations")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start a conversation with someone")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showNewChat = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Start New Chat")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

class ComprehensiveChatsViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let databaseManager = DatabaseManager.shared
    
    func loadChats() {
        guard let userId = AuthManager.shared.currentUserId else { return }
        
        isLoading = true
        
        databaseManager.listenForChats(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] chats in
                    self?.chats = chats
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    func refreshChats() async {
        // Refresh is handled by the real-time listener
        // This method exists for compatibility with refreshable modifier
    }
    
    func deleteChat(_ chat: Chat) {
        Task {
            do {
                try await databaseManager.deleteChat(chat.id)
            } catch {
                self.error = error
            }
        }
    }
    
    func togglePin(_ chat: Chat) {
        Task {
            do {
                try await databaseManager.pinChat(chat.id)
            } catch {
                self.error = error
            }
        }
    }
    
    func markAsRead(_ chat: Chat) {
        Task {
            do {
                try await databaseManager.markChatAsRead(chat.id)
            } catch {
                self.error = error
            }
        }
    }
    
    func clearChats() {
        chats.removeAll()
    }
    
    private var cancellables = Set<AnyCancellable>()
}

// ProfileImageView is now defined in UIComponents.swift

struct ComprehensiveChatsView_Previews: PreviewProvider {
    static var previews: some View {
        ComprehensiveChatsView(showNewChat: .constant(false))
            .environmentObject(SettingsManager.shared)
            .environmentObject(AuthManager.shared)
    }
}
