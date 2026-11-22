import SwiftUI
import Supabase

/// Block / report support (App Store Guideline 1.2).
@MainActor
final class ModerationManager: ObservableObject {
    static let shared = ModerationManager()
    private let client = SupabaseManager.client

    @Published private(set) var blockedIds: Set<String> = []

    private struct BlockRow: Codable { let blocker_id: String; let blocked_id: String }
    private struct ReportRow: Encodable {
        let reporter_id: String
        let reported_id: String
        let message_id: String?
        let reason: String
        let details: String?
    }

    func isBlocked(_ userId: String) -> Bool { blockedIds.contains(userId) }

    func refresh() async {
        guard let me = try? await client.auth.session.user.id.uuidString.lowercased() else { return }
        do {
            let rows: [BlockRow] = try await client.from("blocks").select().eq("blocker_id", value: me).execute().value
            blockedIds = Set(rows.map { $0.blocked_id })
        } catch {
            #if DEBUG
            print("ModerationManager.refresh failed: \(error)")
            #endif
        }
    }

    func block(_ userId: String) async {
        guard let me = try? await client.auth.session.user.id.uuidString.lowercased(), me != userId else { return }
        blockedIds.insert(userId)
        do {
            try await client.from("blocks").upsert(BlockRow(blocker_id: me, blocked_id: userId)).execute()
        } catch {
            blockedIds.remove(userId)
        }
    }

    func unblock(_ userId: String) async {
        guard let me = try? await client.auth.session.user.id.uuidString.lowercased() else { return }
        blockedIds.remove(userId)
        do {
            try await client.from("blocks").delete().eq("blocker_id", value: me).eq("blocked_id", value: userId).execute()
        } catch {
            blockedIds.insert(userId)
        }
    }

    func report(userId: String, messageId: String? = nil, reason: String, details: String?) async -> Bool {
        guard let me = try? await client.auth.session.user.id.uuidString.lowercased() else { return false }
        do {
            try await client.from("reports")
                .insert(ReportRow(reporter_id: me, reported_id: userId, message_id: messageId, reason: reason, details: details))
                .execute()
            return true
        } catch {
            return false
        }
    }
}

struct ReportUserSheet: View {
    let userId: String
    let userName: String
    var messageId: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "Spam"
    @State private var details = ""
    @State private var sent = false
    @State private var failed = false

    private let reasons = ["Spam", "Harassment or bullying", "Inappropriate content", "Impersonation", "Threats or violence", "Other"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Report \(userName)")) {
                    Picker("Reason", selection: $reason) {
                        ForEach(reasons, id: \.self) { Text($0) }
                    }
                    TextField("Details (optional)", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section(footer: Text("Our team reviews reports within 24 hours. You can also block this user.")) {
                    Button("Submit Report") {
                        Task {
                            let ok = await ModerationManager.shared.report(userId: userId, messageId: messageId, reason: reason, details: details.isEmpty ? nil : details)
                            sent = ok
                            failed = !ok
                        }
                    }
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .alert("Report sent", isPresented: $sent) {
                Button("OK") { dismiss() }
            } message: { Text("Thank you. We will review it within 24 hours.") }
            .alert("Couldn't send report", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: { Text("Please check your connection and try again.") }
        }
    }
}

/// Menu used in chat headers and profile screens.
struct UserSafetyMenu: View {
    let userId: String
    let userName: String
    @ObservedObject private var moderation = ModerationManager.shared
    @State private var showReport = false
    @State private var confirmBlock = false

    var body: some View {
        Menu {
            if moderation.isBlocked(userId) {
                Button("Unblock \(userName)") { Task { await moderation.unblock(userId) } }
            } else {
                Button("Block \(userName)", role: .destructive) { confirmBlock = true }
            }
            Button("Report \(userName)") { showReport = true }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .confirmationDialog("Block \(userName)?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) { Task { await moderation.block(userId) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to call or message you, and you won't see their messages.")
        }
        .sheet(isPresented: $showReport) { ReportUserSheet(userId: userId, userName: userName) }
        .task { await moderation.refresh() }
    }
}
