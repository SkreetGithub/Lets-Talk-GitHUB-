import Foundation
import UIKit
import Supabase

final class SupabaseStorageService: ObservableObject {
    static let shared = SupabaseStorageService()

    private let client = SupabaseManager.client
    private let bucket = Config.supabaseStorageBucket

    private init() {}

    // MARK: - Profile Image Upload
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "SupabaseStorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }

        let path = "profile_images/\(userId).jpg"

        _ = try await client.storage
            .from(bucket)
            .upload(
                path: path,
                file: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )

        // Prefer signed URLs in production if your bucket isn't public.
        if let publicURL = try? client.storage.from(bucket).getPublicURL(path: path) {
            return publicURL.absoluteString
        }

        return path
    }

    // MARK: - Profile photo (private)
    //
    // profile-photos/<user id>/<time>.jpg. Every upload gets a new name, so phones that cached
    // the old photo pick up the new one. Older photos in the folder are removed afterwards.

    static let profilePhotosBucket = "profile-photos"

    /// Uploads a square avatar and returns the reference to store in profiles.photo_url.
    func uploadProfilePhoto(_ image: UIImage, userId: String) async throws -> String {
        let square = image.squareAvatar(side: 512)
        guard let data = square.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "SupabaseStorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Couldn't read that photo. Please try another one."])
        }
        let folder = userId.lowercased()
        let path = "\(folder)/\(Int(Date().timeIntervalSince1970)).jpg"
        _ = try await client.storage
            .from(Self.profilePhotosBucket)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))
        let reference = Self.mediaScheme + Self.profilePhotosBucket + "/" + path
        await AvatarImageCache.shared.store(square, data: data, for: reference)
        await removeProfilePhotos(userId: userId, keeping: path)
        return reference
    }

    /// Deletes this user's stored photos (all of them, or all but `keeping`).
    func removeProfilePhotos(userId: String, keeping: String? = nil) async {
        let folder = userId.lowercased()
        guard let files = try? await client.storage.from(Self.profilePhotosBucket).list(path: folder) else { return }
        var old: [String] = []
        for file in files {
            let name: String? = file.name
            guard let name, !name.isEmpty else { continue }
            let path = "\(folder)/\(name)"
            if path != keeping { old.append(path) }
        }
        guard !old.isEmpty else { return }
        _ = try? await client.storage.from(Self.profilePhotosBucket).remove(paths: old)
    }

    // MARK: - Chat Media (private)
    //
    // Photos and files go to the private `chat-files` bucket, voice messages to `chat-audio`,
    // at <chat id>/<message id>.<ext>. The database only lets the two people in that chat read
    // them, so a message stores a reference ("lettalk-media://<bucket>/<path>") instead of a
    // public link, and the app opens it through a signed URL that works for 1 hour.
    // (Chat media used to sit in the PUBLIC bucket, where anyone with the link could open it.)
    // Uploads and signed URLs are sent with the signed-in user's access token by the Supabase client.

    static let mediaScheme = "lettalk-media://"
    static let chatFilesBucket = "chat-files"
    static let chatAudioBucket = "chat-audio"

    func uploadChatImage(_ image: UIImage, chatId: String, messageId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "SupabaseStorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        return try await uploadChatMedia(imageData, bucket: Self.chatFilesBucket,
                                         path: "\(chatId)/\(messageId).jpg", contentType: "image/jpeg")
    }

    func uploadChatFile(_ data: Data, chatId: String, fileName: String, contentType: String) async throws -> String {
        try await uploadChatMedia(data, bucket: Self.chatFilesBucket, path: "\(chatId)/\(fileName)", contentType: contentType)
    }

    func uploadVoiceMessage(_ data: Data, chatId: String, messageId: String) async throws -> String {
        try await uploadChatMedia(data, bucket: Self.chatAudioBucket, path: "\(chatId)/\(messageId).m4a", contentType: "audio/mp4")
    }

    private func uploadChatMedia(_ data: Data, bucket: String, path: String, contentType: String) async throws -> String {
        _ = try await client.storage
            .from(bucket)
            .upload(path, data: data, options: FileOptions(contentType: contentType, upsert: false))
        return Self.mediaScheme + bucket + "/" + path
    }

    // MARK: - Opening chat media

    private var signedCache: [String: (url: URL, expires: Date)] = [:]
    private let cacheLock = NSLock()

    /// A URL the app can load for an attachment. Private media gets a fresh 1-hour signed URL
    /// (reused for 55 minutes); older plain links are returned as they are.
    func url(for reference: String) async throws -> URL {
        guard reference.hasPrefix(Self.mediaScheme) else {
            guard let url = URL(string: reference) else { throw URLError(.badURL) }
            return url
        }
        if let cached = cachedURL(reference) { return cached }

        let location = String(reference.dropFirst(Self.mediaScheme.count))
        guard let slash = location.firstIndex(of: "/") else { throw URLError(.badURL) }
        let bucket = String(location[..<slash])
        let path = String(location[location.index(after: slash)...])

        let signed = try await client.storage.from(bucket).createSignedURL(path: path, expiresIn: 3600)
        cacheLock.withLock { signedCache[reference] = (signed, Date().addingTimeInterval(55 * 60)) }
        return signed
    }

    private func cachedURL(_ reference: String) -> URL? {
        cacheLock.withLock {
            guard let hit = signedCache[reference], hit.expires > Date() else { return nil }
            return hit.url
        }
    }
}
