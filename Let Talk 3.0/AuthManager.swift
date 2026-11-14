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
    #if DEBUG
    @Published var isDemoMode = false
    #endif
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
                    await fetchUserProfile(userId: session.user.id.uuidString.lowercased())
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
            await fetchUserProfile(userId: session.user.id.uuidString.lowercased())
        } catch {
            await MainActor.run { self.error = error }
            throw error
        }
    }

    /// Creates the account and its profile. Returns `true` when Supabase returned a session
    /// (user is signed in now) and `false` when email confirmation is required first.
    /// Name and phone are also stored in the auth user's metadata, so they are not lost when
    /// the profile row can only be created after the email is confirmed.
    @discardableResult
    func signUp(email: String, password: String, name: String, phone: String = "",
                gender: VoiceGender? = nil) async throws -> Bool {
        guard NetworkMonitorService.shared.isConnected else { throw AuthError.networkError }
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            var metadata: [String: AnyJSON] = ["name": .string(name), "phone": .string(phone)]
            if let gender { metadata["gender"] = .string(gender.rawValue) }
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: metadata
            )

            guard let session = response.session else {
                // Email confirmation is on: no session until the user taps the link.
                await MainActor.run {
                    self.isAuthenticated = false
                    self.needsPhoneVerification = false
                }
                return false
            }

            let userId = session.user.id.uuidString.lowercased()
            try await upsertProfile(ProfileRow(
                id: userId,
                email: email,
                name: name,
                phone: phone,
                photoURL: nil,
                createdAt: Date(),
                lastSeen: Date(),
                isOnline: true,
                deviceTokens: nil,
                savedPhoneNumbers: [],
                gender: gender?.rawValue,
                voiceId: gender?.defaultVoiceId
            ))
            // Sets isAuthenticated / needsPhoneVerification from the saved phone number.
            await fetchUserProfile(userId: userId)
            return true
        } catch {
            await MainActor.run { self.error = error }
            throw error
        }
    }

    /// Sign in with Apple, exchanged for a Supabase session. Requires the Apple provider
    /// to be enabled in Supabase (Authentication -> Providers -> Apple).
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws {
        guard NetworkMonitorService.shared.isConnected else { throw AuthError.networkError }
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.custom("Apple did not return an identity token.")
        }
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: rawNonce)
            )
            let userId = session.user.id.uuidString.lowercased()
            await fetchUserProfile(userId: userId)

            // Apple only sends the name on the first sign-in; keep it if we have it.
            if let parts = credential.fullName {
                let name = [parts.givenName, parts.familyName].compactMap { $0 }.joined(separator: " ")
                if !name.isEmpty, currentUser?.name == "User" {
                    try? await updateProfileFields(userId: userId, fields: ["name": .string(name)])
                    await fetchUserProfile(userId: userId)
                }
            }
        } catch {
            await MainActor.run { self.error = error }
            throw error
        }
    }

    /// Sign in with Google through Supabase Auth (OAuth + PKCE in an in-app browser sheet).
    /// Requires the Google provider in Supabase (Authentication → Providers → Google) and
    /// lettalk://auth-callback in the allowed Redirect URLs. New users then follow the same
    /// path as Sign in with Apple: profile created from the Google name/email, then the
    /// phone-number step (needsPhoneVerification), then the translation consent on first use.
    /// Returns false if the user closed the Google sheet.
    @discardableResult
    func signInWithGoogle() async throws -> Bool {
        guard NetworkMonitorService.shared.isConnected else { throw AuthError.networkError }
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let session = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: Config.authCallbackURL,
                queryParams: [(name: "prompt", value: "select_account")]
            )
            await fetchUserProfile(userId: session.user.id.uuidString.lowercased())
            return true
        } catch {
            if let webError = error as? ASWebAuthenticationSessionError, webError.code == .canceledLogin {
                return false
            }
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
        // Settings › Show Online Status off: always appear offline to others.
        let isOnline = isOnline && SettingsManager.shared.settings.privacy.showOnlineStatus

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
        // Server-side deletion (Edge Function `delete-account`, service role) removes the auth user
        // and all of the user's data: messages, calls, contacts, blocks, tokens, storage, profile.
        guard currentUserId != nil else { return }
        try await Backend.deleteAccount()
        try? await signOut()
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
            self.needsPhoneVerification = false
        }
    }

    // MARK: - Session

    func refreshUserSession() async {
        do {
            let session = try await client.auth.session
            await fetchUserProfile(userId: session.user.id.uuidString.lowercased())
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

    /// Loads the signed-in user's profile.
    ///
    /// Previously any failure here (including a date-decoding failure that happened on EVERY
    /// load) was treated as "profile missing": the code upserted a blank profile over the real
    /// one (name "User", phone "") and set isAuthenticated = false. That is why every relaunch
    /// landed on Sign In. Now:
    ///  - the row is decoded with the Postgres date parser,
    ///  - a blank profile is only INSERTED when no row exists (never overwrites),
    ///  - a network/server error keeps the user signed in with their existing session.
    private func fetchUserProfile(userId: String) async {
        let rows: [ProfileRow]
        do {
            let response = try await client.from("profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
            rows = try PostgresDate.decoder.decode([ProfileRow].self, from: response.data)
        } catch {
            debugLog("Profile fetch failed:", error)
            let sessionUser = try? await client.auth.session.user
            await MainActor.run {
                self.error = error
                // The Supabase session is valid; don't bounce the user to Sign In over a
                // transient failure. Keep the last known profile, or a minimal one.
                if self.currentUser == nil {
                    self.currentUser = User(id: userId, email: sessionUser?.email ?? "",
                                            name: "User", phone: "", photoURL: nil)
                }
                self.needsPhoneVerification = false
                self.isAuthenticated = true
            }
            return
        }

        if let row = rows.first {
            await MainActor.run {
                self.currentUser = row.asUser
                self.needsPhoneVerification = row.phone.isEmpty
                self.isAuthenticated = !row.phone.isEmpty
            }
            return
        }

        // No profile row yet (e.g. first sign-in after confirming email). Create one from the
        // auth user's metadata, insert-only so it can never replace a real profile.
        let user = try? await client.auth.session.user
        // "name" from email sign-up; "full_name" is what Google (and other OAuth providers) send.
        let name = Self.metadataString(user?.userMetadata["name"])
            ?? Self.metadataString(user?.userMetadata["full_name"])
            ?? "User"
        let phone = Self.metadataString(user?.userMetadata["phone"]) ?? ""
        let email = user?.email ?? ""
        let gender = Self.metadataString(user?.userMetadata["gender"]).flatMap(VoiceGender.init(rawValue:))
        let newRow = ProfileRow(
            id: userId, email: email, name: name, phone: phone, photoURL: nil,
            createdAt: Date(), lastSeen: Date(), isOnline: true,
            deviceTokens: nil, savedPhoneNumbers: [],
            gender: gender?.rawValue, voiceId: gender?.defaultVoiceId
        )
        do {
            _ = try await client.from("profiles")
                .upsert(newRow, onConflict: "id", ignoreDuplicates: true)
                .execute()
        } catch {
            debugLog("Profile create failed:", error)
            await MainActor.run { self.error = error }
        }
        await MainActor.run {
            self.currentUser = newRow.asUser
            self.needsPhoneVerification = phone.isEmpty
            self.isAuthenticated = !phone.isEmpty
        }
    }

    private static func metadataString(_ value: AnyJSON?) -> String? {
        guard case let .string(text)? = value, !text.isEmpty else { return nil }
        return text
    }

    private func upsertProfile(_ row: ProfileRow) async throws {
        _ = try await client.from("profiles")
            .upsert(row)
            .execute()
    }

    /// Saves "my language" to the profile, so message notifications arrive translated into it.
    func syncLanguage(_ code: String) async {
        guard let userId = currentUserId else { return }
        struct LanguageUpdate: Encodable { let language: String }
        _ = try? await client.from("profiles")
            .update(LanguageUpdate(language: code))
            .eq("id", value: userId)
            .execute()
    }

    /// Saves the translation voice others hear for this user ("male-1" … "female-8").
    func updateVoice(_ voiceId: String) async throws {
        guard let userId = currentUserId else { throw AuthError.userNotFound }
        let gender: VoiceGender = voiceId.hasPrefix(VoiceGender.female.rawValue) ? .female : .male
        struct VoiceUpdate: Encodable {
            let gender: String
            let voice_id: String
        }
        _ = try await client.from("profiles")
            .update(VoiceUpdate(gender: gender.rawValue, voice_id: voiceId))
            .eq("id", value: userId)
            .execute()
        await MainActor.run {
            self.currentUser?.gender = gender
            self.currentUser?.voiceId = voiceId
        }
    }

    private func updateProfileFields(userId: String, fields: [String: ProfileValue]) async throws {
        // Convert ProfileValue to ProfileUpdate struct
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
    /// Kind of voice others hear for this user's translated speech (nil for older accounts).
    var gender: VoiceGender?
    /// Selected translation voice, e.g. "female-3" (nil = the default for `gender`).
    var voiceId: String?

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
    // Optional so rows saved before these columns existed still decode, and nil values are
    // left out of upserts instead of overwriting a saved choice.
    var gender: String? = nil
    var voiceId: String? = nil

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
        case gender
        case voiceId = "voice_id"
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
        u.gender = gender.flatMap(VoiceGender.init(rawValue:))
        u.voiceId = voiceId
        return u
    }
}

extension ProfileRow {
    /// Lenient decoder: a null or missing column falls back to a default instead of failing
    /// the whole profile load. (Defined in an extension so the memberwise init is kept.)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = (try? c.decodeIfPresent(String.self, forKey: .email)) ?? ""
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "User"
        phone = (try? c.decodeIfPresent(String.self, forKey: .phone)) ?? ""
        photoURL = try? c.decodeIfPresent(String.self, forKey: .photoURL)
        createdAt = (try? c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        lastSeen = (try? c.decodeIfPresent(Date.self, forKey: .lastSeen)) ?? Date()
        isOnline = (try? c.decodeIfPresent(Bool.self, forKey: .isOnline)) ?? false
        deviceTokens = try? c.decodeIfPresent([String].self, forKey: .deviceTokens)
        savedPhoneNumbers = (try? c.decodeIfPresent([SavedPhoneNumber].self, forKey: .savedPhoneNumbers)) ?? []
    }
}

private enum ProfileValue {
    case string(String)
    case bool(Bool)
    case number(Double)
    case array([ProfileValue])
    case object([String: ProfileValue])
    case null

    static func any(_ value: Any) -> ProfileValue {
        switch value {
        case let v as String: return .string(v)
        case let v as Bool: return .bool(v)
        case let v as Int: return .number(Double(v))
        case let v as Double: return .number(v)
        case let v as [Any]: return .array(v.map(ProfileValue.any))
        case let v as [String: Any]:
            return .object(v.mapValues(ProfileValue.any))
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
