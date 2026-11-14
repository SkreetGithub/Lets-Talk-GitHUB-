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
