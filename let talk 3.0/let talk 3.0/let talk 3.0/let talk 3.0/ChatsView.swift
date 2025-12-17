import SwiftUI
import Combine

struct ChatsView: View {
    @StateObject private var viewModel = ChatsViewModel()
    @Binding var showNewChat: Bool
    @State private var searchText = ""
    @State private var selectedChat: Chat?
    @State private var showDeleteConfirmation = false
    @State private var chatToDelete: Chat?
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.chats.isEmpty {
                EmptyChatsView(showNewChat: $showNewChat)
            } else {
                chatsList
            }
        }
        .searchable(text: $searchText, prompt: "Search chats")
        .refreshable {
            await viewModel.refreshChats()
        }
    }
    
    private var chatsList: some View {
        List {
            ForEach(filteredChats) { chat in
                ChatRow(chat: chat, settingsManager: SettingsManager.shared)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedChat = chat
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            chatToDelete = chat
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        if !chat.isPinned {
                            Button {
                                viewModel.pinChat(chat)
                            } label: {
                                Label("Pin", systemImage: "pin")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            viewModel.markAsRead(chat)
                        } label: {
                            Label("Read", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
            }
        }
        .listStyle(.plain)
        .sheet(item: $selectedChat) { chat in
            NavigationView {
                ChatDetailView(chat: chat)
            }
        }
        .alert("Delete Chat", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let chat = chatToDelete {
                    viewModel.deleteChat(chat)
                }
            }
        } message: {
            Text("Are you sure you want to delete this chat? This action cannot be undone.")
        }
    }
    
    private var filteredChats: [Chat] {
        if searchText.isEmpty {
            return viewModel.chats
        } else {
            return viewModel.chats.filter { chat in
                chat.title.localizedCaseInsensitiveContains(searchText) ||
                chat.lastMessage?.content.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
}

// ChatRow and EmptyChatsView are now defined in ComprehensiveChatsView.swift

class ChatsViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    private let databaseManager = DatabaseManager.shared
    
    init() {
        setupChatsSubscription()
    }
    
    private func setupChatsSubscription() {
        guard let userId = AuthManager.shared.currentUserId else { return }
        
        databaseManager.listenForChats(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self.error = error
                }
            } receiveValue: { [weak self] chats in
                self?.chats = chats.sorted { $0.lastUpdated > $1.lastUpdated }
            }
            .store(in: &cancellables)
    }
    
    func refreshChats() async {
        // Implement manual refresh logic if needed
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
    
    func pinChat(_ chat: Chat) {
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
}

// MARK: - Missing Components
// Note: ProfileImageView is defined in UIComponents.swift

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    
    func loadImage(from url: String) {
        // Implement image loading logic
    }
}

struct ChatsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatsView(showNewChat: .constant(false))
    }
}
