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
                    Button(action: { showNewChat = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New chat")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        // New Chat sheet is presented once, by MainTabView (it owns showNewChat).
        // Same Settings screen as More › Settings (there used to be two different ones).
        .sheet(isPresented: $showSettings) {
            UnifiedSettingsView(translationViewModel: UnifiedTranslationViewModel())
                .environmentObject(settingsManager)
                .environmentObject(authManager)
        }
        // Full screen, like a chat opened from Contacts (the chat screen has its own back button).
        .fullScreenCover(item: $selectedChat) { chat in
            ChatDetailView(chat: chat)
        }
        .alert("Chats", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .refreshable {
            await viewModel.refreshChats()
        }
        .onAppear {
            viewModel.loadChats()
        }
        .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
            if newValue {
                viewModel.loadChats()
            } else {
                viewModel.clearChats()
            }
        }
    }
    
    private var chatsList: some View {
        List {
            ForEach(filteredChats) { chat in
                ChatRow(chat: chat, title: viewModel.title(for: chat), photoURL: viewModel.photoURL(for: chat))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        KeyboardDismisser.dismiss()
                        selectedChat = chat
                    }
                    // Long-press menu instead of row swipes: horizontal swipes switch tabs.
                    .contextMenu {
                        Button {
                            viewModel.markAsRead(chat)
                        } label: {
                            Label("Mark as Read", systemImage: "checkmark.circle")
                        }
                        .disabled(chat.unreadCount == 0)
                        
                        Button {
                            viewModel.togglePin(chat)
                        } label: {
                            Label(chat.isPinned ? "Unpin" : "Pin",
                                  systemImage: chat.isPinned ? "pin.slash" : "pin")
                        }
                        
                        Button(role: .destructive) {
                            viewModel.deleteChat(chat)
                        } label: {
                            Label("Delete Chat", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, DS.floatingTabBarClearance, for: .scrollContent)   // last row scrolls clear of the tab bar
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
                viewModel.title(for: chat).localizedCaseInsensitiveContains(searchText) ||
                chat.lastMessage?.content.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
}

struct ChatRow: View {
    let chat: Chat
    /// The other person's name (chats used to all be titled "Chat").
    let title: String
    let photoURL: String?
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            ProfileImageView(
                imageURL: photoURL ?? chat.imageURL,
                placeholderText: title.prefix(1).uppercased()
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
                    Text(title)
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
        EmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "No Conversations",
            message: "Start a conversation with someone.",
            actionTitle: "Start New Chat",
            action: { showNewChat = true }
        )
        .background(Color(.systemGroupedBackground))
    }
}

class ComprehensiveChatsViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Other participants' names and photos, by user ID.
    @Published private var names: [String: String] = [:]
    @Published private var photos: [String: String] = [:]
    
    private let databaseManager = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var lookedUp: Set<String> = []
    
    func loadChats() {
        guard let userId = AuthManager.shared.currentUserId else { return }
        if chats.isEmpty { isLoading = true }
        cancellables.removeAll()   // one poller at a time (each onAppear used to add another)
        
        databaseManager.listenForChats(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                },
                receiveValue: { [weak self] chats in
                    guard let self else { return }
                    self.chats = chats
                    self.isLoading = false
                    self.lookUpNames(for: chats)
                }
            )
            .store(in: &cancellables)
    }
    
    func refreshChats() async {
        // The list polls every few seconds; pull-to-refresh just restarts it immediately.
        await MainActor.run { loadChats() }
    }
    
    func otherUserId(in chat: Chat) -> String? {
        let me = AuthManager.shared.currentUserId?.lowercased()
        return chat.participants.first { $0.lowercased() != me }
    }
    
    func title(for chat: Chat) -> String {
        guard let other = otherUserId(in: chat) else { return "Chat" }
        if let name = names[other], !name.isEmpty { return name }
        if let contact = ContactManager.shared.contacts.first(where: { $0.userId?.lowercased() == other.lowercased() }) {
            return contact.name
        }
        return "Let Talk User"
    }
    
    func photoURL(for chat: Chat) -> String? {
        otherUserId(in: chat).flatMap { photos[$0] }
    }
    
    private func lookUpNames(for chats: [Chat]) {
        let missing = Set(chats.compactMap(otherUserId(in:))).subtracting(lookedUp)
        guard !missing.isEmpty else { return }
        lookedUp.formUnion(missing)
        for userId in missing {
            Task {
                guard let user = try? await databaseManager.getUser(id: userId) else { return }
                await MainActor.run {
                    self.names[userId] = user.name
                    if let photo = user.photoURL { self.photos[userId] = photo }
                }
            }
        }
    }
    
    func deleteChat(_ chat: Chat) {
        chats.removeAll { $0.id == chat.id }
        Task {
            do {
                try await databaseManager.deleteChat(chat.id)
            } catch {
                await MainActor.run { self.errorMessage = "Couldn't delete the chat. Please try again." }
            }
        }
    }
    
    func togglePin(_ chat: Chat) {
        let pinned = !chat.isPinned
        if let index = chats.firstIndex(where: { $0.id == chat.id }) { chats[index].isPinned = pinned }
        Task {
            do {
                try await databaseManager.setChatPinned(chat.id, pinned: pinned)
            } catch {
                await MainActor.run { self.errorMessage = "Couldn't update the chat. Please try again." }
            }
        }
    }
    
    func markAsRead(_ chat: Chat) {
        if let index = chats.firstIndex(where: { $0.id == chat.id }) { chats[index].unreadCount = 0 }
        Task {
            try? await databaseManager.markChatAsRead(chat.id)
        }
    }
    
    func clearChats() {
        cancellables.removeAll()
        chats.removeAll()
    }
}

// ProfileImageView is now defined in UIComponents.swift

struct ComprehensiveChatsView_Previews: PreviewProvider {
    static var previews: some View {
        ComprehensiveChatsView(showNewChat: .constant(false))
            .environmentObject(SettingsManager.shared)
            .environmentObject(AuthManager.shared)
    }
}
