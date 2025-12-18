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

    // MARK: - Chat Media Upload
    func uploadChatImage(_ image: UIImage, chatId: String, messageId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "SupabaseStorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }

        let path = "chat_images/\(chatId)/\(messageId).jpg"

        _ = try await client.storage
            .from(bucket)
            .upload(
                path: path,
                file: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )

        if let publicURL = try? client.storage.from(bucket).getPublicURL(path: path) {
            return publicURL.absoluteString
        }

        return path
    }

    // MARK: - File Upload
    func uploadFile(_ data: Data, fileName: String, folder: String, contentType: String? = nil) async throws -> String {
        let path = "\(folder)/\(fileName)"

        _ = try await client.storage
            .from(bucket)
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: contentType, upsert: true)
            )

        if let publicURL = try? client.storage.from(bucket).getPublicURL(path: path) {
            return publicURL.absoluteString
        }

        return path
    }
}

