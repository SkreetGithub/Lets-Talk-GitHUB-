import SwiftUI
import UIKit
import AuthenticationServices
import Supabase

final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isDemoMode = false
    @Published var needsPhoneVerification = false

    private let client = SupabaseManager.client
    private var authListenerTask: Task<Void, Never>?

    private init() {
        observeAuthState()
        Task { await refreshUserSession() }
    }

    var currentUserId: String? {
        currentUser?.id
    }

    // MARK: - Auth State

    private func observeAuthState() {
        authListenerTask?.cancel()
        authListenerTask = Task { [weak self] in
            guard let self else { return }

            // Supabase emits auth state changes as an async sequence.
            for await (_, session) in client.auth.authStateChanges {
                await MainActor.run {
                    self.isLoading = true
                }
                defer {
                    Task { @MainActor in self.isLoading = false }
                }

                if let session = session {
                    await fetchUserProfile(userId: session.user.id.uuidString)
                } else {
                    await MainActor.run {
                        self.currentUser = nil
                        self.isAuthenticated = false
                        self.needsPhoneVerification = false
                    }
                }
            }
        }
    }

    // MARK: - Auth Actions

    func signIn(email: String, password: String) async throws {
        guard NetworkMonitorService.shared.isConnected else { throw AuthError.networkError }
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let session = try await client.auth.signIn(email: email, password: password)
            await fetchUserProfile(userId: session.user.id.uuidString)
        } catch {
            await MainActor.run { self.error = error }
            throw error
        }
    }

    func signUp(email: String, password: String, name: String) async throws {
        guard NetworkMonitorService.shared.isConnected else { throw AuthError.networkError }
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response = try await client.auth.signUp(email: email, password: password)

            // If email confirmation is enabled, Supabase may return no session.
            if let session = response.session {
                let userId = session.user.id.uuidString
                try await upsertProfile(ProfileRow(
                    id: userId,
                    email: email,
                    name: name,
                    phone: "",
                    photoURL: nil,
                    createdAt: Date(),
                    lastSeen: Date(),
                    isOnline: true,
                    deviceTokens: nil,
                    savedPhoneNumbers: []
                ))
                await fetchUserProfile(userId: userId)

                await MainActor.run {
                    self.needsPhoneVerification = true
                }
            } else {
                // No session yet; user must confirm email.
                await MainActor.run {
                    self.isAuthenticated = false
                    self.needsPhoneVerification = false
                }
            }
        } catch {
            await MainActor.run { self.error = error }
            throw error
        }
    }

    func completePhoneVerification(phoneNumber: String) async throws {
        guard let userId = currentUserId else { throw AuthError.userNotFound }

        // NOTE: This app's "phone verification" flow is local UI-driven.
        // If you want true SMS verification, switch this to Supabase phone OTP.
        try await updateProfileFields(userId: userId, fields: [
            "phone": .string(phoneNumber)
        ])

        await fetchUserProfile(userId: userId)
        await MainActor.run {
            self.needsPhoneVerification = false
            self.isAuthenticated = true
        }
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                self.error = nil
                self.needsPhoneVerification = false
            }
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                self.error = error
                self.needsPhoneVerification = false
            }
            throw error
        }
    }

    func resetPassword(email: String) async throws {
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            try await client.auth.resetPasswordForEmail(email)
        } catch {
            await MainActor.run { self.error = error }
            throw error
        }
    }

    // MARK: - Profile

    func updateUserProfile(
        name: String? = nil,
        phone: String? = nil,
        photoURL: String? = nil,
        profileImage: UIImage? = nil
    ) async throws {
        guard let userId = currentUserId else { return }

        var update = ProfileUpdate()
        if let name { update.name = name }
        if let phone { update.phone = phone }

        if let profileImage {
            let url = try await SupabaseStorageService.shared.uploadProfileImage(profileImage, userId: userId)
            update.photoURL = url
        } else if let photoURL {
            update.photoURL = photoURL
        }

        _ = try await client.from("profiles")
            .update(update)
            .eq("id", value: userId)
            .execute()

        await fetchUserProfile(userId: userId)
    }

    func savePhoneNumber(_ phoneNumber: SavedPhoneNumber) async throws {
        guard let userId = currentUserId else { return }

        var current = currentUser?.savedPhoneNumbers ?? []
        current.append(phoneNumber)

        // Store as JSONB array in `profiles.saved_phone_numbers`.
        let updateData = ProfileUpdate(savedPhoneNumbers: current)
        
        _ = try await client.from("profiles")
            .update(updateData)
            .eq("id", value: userId)
            .execute()

        await fetchUserProfile(userId: userId)
    }

    func updateOnlineStatus(isOnline: Bool) {
        guard let userId = currentUserId else { return }

        Task {
            let update = ProfileUpdate(
                isOnline: isOnline,
                lastSeen: Date()
            )
            try? await client.from("profiles")
                .update(update)
                .eq("id", value: userId)
                .execute()
        }
    }

    // MARK: - Account Management

    func deleteAccount() async throws {
        // Client-side deletion of the auth user requires a service role key (server-side).
        // Here we delete the profile row and sign out.
        guard let userId = currentUserId else { return }

        _ = try await client.from("profiles")
            .delete()
            .eq("id", value: userId)
            .execute()

        try await signOut()
    }

    // MARK: - Session

    func refreshUserSession() async {
        do {
            let session = try await client.auth.session
            await fetchUserProfile(userId: session.user.id.uuidString)
        } catch {
            // No session available or refresh failed.
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.needsPhoneVerification = false
            }
        }
    }

    // MARK: - Private Supabase Helpers

    private func fetchUserProfile(userId: String) async {
        do {
            let response = try await client.from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()

            let row = try JSONDecoder().decode(ProfileRow.self, from: response.data)

            await MainActor.run {
                self.currentUser = row.asUser
                self.needsPhoneVerification = row.phone.isEmpty
                self.isAuthenticated = !row.phone.isEmpty
            }
        } catch {
            // If the profile doesn't exist yet, create a minimal one.
            do {
                let email = (try? await client.auth.session)?.user.email ?? ""
                try await upsertProfile(ProfileRow(
                    id: userId,
                    email: email,
                    name: "User",
                    phone: "",
                    photoURL: nil,
                    createdAt: Date(),
                    lastSeen: Date(),
                    isOnline: true,
                    deviceTokens: nil,
                    savedPhoneNumbers: []
                ))

                await MainActor.run {
                    self.currentUser = User(id: userId, email: email, name: "User", phone: "", photoURL: nil)
                    self.needsPhoneVerification = true
                    self.isAuthenticated = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.currentUser = User(id: userId, email: "", name: "User", phone: "", photoURL: nil)
                    self.needsPhoneVerification = true
                    self.isAuthenticated = false
                }
            }
        }
    }

    private func upsertProfile(_ row: ProfileRow) async throws {
        _ = try await client.from("profiles")
            .upsert(row)
            .execute()
    }

    private func updateProfileFields(userId: String, fields: [String: AnyJSON]) async throws {
        // Convert AnyJSON to ProfileUpdate struct
        var update = ProfileUpdate()
        
        for (key, value) in fields {
            switch (key, value) {
            case ("name", .string(let v)):
                update.name = v
            case ("phone", .string(let v)):
                update.phone = v
            case ("photo_url", .string(let v)):
                update.photoURL = v
            case ("is_online", .bool(let v)):
                update.isOnline = v
            case ("last_seen", .string(let v)):
                if let date = ISO8601DateFormatter().date(from: v) {
                    update.lastSeen = date
                }
            default:
                break
            }
        }

        _ = try await client.from("profiles")
            .update(update)
            .eq("id", value: userId)
            .execute()
    }

    // MARK: - Error Handling

    func handleAuthError(_ error: Error) -> String {
        if let authError = error as? AuthError {
            return authError.localizedDescription
        }

        // Supabase errors are surfaced as regular Swift errors; show a safe default.
        return error.localizedDescription
    }
}

// MARK: - Saved Phone Number

struct SavedPhoneNumber: Identifiable, Codable {
    let id = UUID()
    let number: String
    let countryCode: String
    let areaCode: String
    let state: String?
    let country: String
    let createdAt: Date

    init(number: String, countryCode: String, areaCode: String, state: String? = nil, country: String) {
        self.number = number
        self.countryCode = countryCode
        self.areaCode = areaCode
        self.state = state
        self.country = country
        self.createdAt = Date()
    }
}

// MARK: - Auth Error Types

enum AuthError: Error, LocalizedError {
    case networkError
    case googleSignInNotAvailable
    case userNotFound
    case biometricNotAvailable
    case biometricFailed
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error occurred"
        case .googleSignInNotAvailable:
            return "Google Sign-In is not available."
        case .userNotFound:
            return "User not found"
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .biometricFailed:
            return "Biometric authentication failed"
        case .custom(let message):
            return message
        }
    }
}

// MARK: - Models

struct User: Identifiable, Codable {
    let id: String
    let email: String
    var name: String
    var phone: String
    var photoURL: String?
    let createdAt: Date
    var lastSeen: Date?
    var isOnline: Bool
    var deviceTokens: [String]?
    var settings: UserSettings?
    var savedPhoneNumbers: [SavedPhoneNumber] = []

    struct UserSettings: Codable {
        var notifications: Bool
        var language: String
        var theme: String
        var autoTranslate: Bool
    }

    init(
        id: String,
        email: String,
        name: String,
        phone: String,
        photoURL: String? = nil,
        createdAt: Date = Date(),
        lastSeen: Date? = nil,
        isOnline: Bool = false
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.phone = phone
        self.photoURL = photoURL
        self.createdAt = createdAt
        self.lastSeen = lastSeen
        self.isOnline = isOnline
    }
}

// MARK: - Supabase Row + JSON Helpers

private struct ProfileUpdate: Codable {
    var name: String?
    var phone: String?
    var photoURL: String?
    var isOnline: Bool?
    var lastSeen: Date?
    var savedPhoneNumbers: [SavedPhoneNumber]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case phone
        case photoURL = "photo_url"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
        case savedPhoneNumbers = "saved_phone_numbers"
    }
    
    init(name: String? = nil, phone: String? = nil, photoURL: String? = nil, isOnline: Bool? = nil, lastSeen: Date? = nil, savedPhoneNumbers: [SavedPhoneNumber]? = nil) {
        self.name = name
        self.phone = phone
        self.photoURL = photoURL
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.savedPhoneNumbers = savedPhoneNumbers
    }
}

private struct ProfileRow: Codable {
    let id: String
    let email: String
    let name: String
    let phone: String
    let photoURL: String?
    let createdAt: Date
    let lastSeen: Date
    let isOnline: Bool
    let deviceTokens: [String]?
    let savedPhoneNumbers: [SavedPhoneNumber]

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case phone
        case photoURL = "photo_url"
        case createdAt = "created_at"
        case lastSeen = "last_seen"
        case isOnline = "is_online"
        case deviceTokens = "device_tokens"
        case savedPhoneNumbers = "saved_phone_numbers"
    }

    var asUser: User {
        var u = User(
            id: id,
            email: email,
            name: name,
            phone: phone,
            photoURL: photoURL,
            createdAt: createdAt,
            lastSeen: lastSeen,
            isOnline: isOnline
        )
        u.deviceTokens = deviceTokens
        u.savedPhoneNumbers = savedPhoneNumbers
        return u
    }
}

private enum AnyJSON {
    case string(String)
    case bool(Bool)
    case number(Double)
    case array([AnyJSON])
    case object([String: AnyJSON])
    case null

    static func any(_ value: Any) -> AnyJSON {
        switch value {
        case let v as String: return .string(v)
        case let v as Bool: return .bool(v)
        case let v as Int: return .number(Double(v))
        case let v as Double: return .number(v)
        case let v as [Any]: return .array(v.map(AnyJSON.any))
        case let v as [String: Any]:
            return .object(v.mapValues(AnyJSON.any))
        default:
            return .null
        }
    }

    var value: Any {
        switch self {
        case .string(let s): return s
        case .bool(let b): return b
        case .number(let n): return n
        case .array(let a): return a.map { $0.value }
        case .object(let o): return o.mapValues { $0.value }
        case .null: return NSNull()
        }
    }
}
