import SwiftUI
import UIKit
import CryptoKit

// Profile photos: loading, caching, looking up by user, picking, and the ringing glow.
//
// A photo is stored as a reference ("lettalk-media://profile-photos/<user>/<time>.jpg") in
// profiles.photo_url. The bucket is private, so the app opens it with a short-lived signed URL.
// Every new upload gets a new file name, so the cache key changes when someone changes photo.

// MARK: - Initials

enum Initials {
    /// "Demetrius Hollins" -> "DH", "Demetrius" -> "D", "" -> "?".
    static func from(_ name: String) -> String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" }).filter { $0.first?.isLetter == true || $0.first?.isNumber == true }
        guard let first = words.first?.first else { return "?" }
        if words.count >= 2, let last = words.last?.first {
            return "\(first)\(last)".uppercased()
        }
        return String(first).uppercased()
    }
}

// MARK: - Image cache

/// Keeps avatars in memory and on disk (Caches/avatars), so each photo downloads once.
actor AvatarImageCache {
    static let shared = AvatarImageCache()

    // NSCache is thread-safe, so the memory cache can be read without waiting on the actor.
    nonisolated(unsafe) private let memory = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private let folder: URL

    init() {
        memory.countLimit = 300
        folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// Already-loaded image, without any network or disk work (for the first frame).
    nonisolated func cachedInMemory(_ reference: String) -> UIImage? {
        memory.object(forKey: reference as NSString)
    }

    func image(for reference: String) async -> UIImage? {
        if let hit = memory.object(forKey: reference as NSString) { return hit }
        if let running = inFlight[reference] { return await running.value }

        let file = folder.appendingPathComponent(Self.fileName(for: reference))
        let task = Task<UIImage?, Never> {
            if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
                return image
            }
            do {
                let url = try await SupabaseStorageService.shared.url(for: reference)
                let (data, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
                      let image = UIImage(data: data) else { return nil }
                try? data.write(to: file, options: .atomic)
                return image
            } catch {
                return nil
            }
        }
        inFlight[reference] = task
        let image = await task.value
        inFlight[reference] = nil
        if let image { memory.setObject(image, forKey: reference as NSString) }
        return image
    }

    /// Puts a just-uploaded photo straight into the cache, so it shows without downloading.
    func store(_ image: UIImage, data: Data, for reference: String) {
        memory.setObject(image, forKey: reference as NSString)
        try? data.write(to: folder.appendingPathComponent(Self.fileName(for: reference)), options: .atomic)
    }

    private static func fileName(for reference: String) -> String {
        SHA256.hash(data: Data(reference.utf8)).map { String(format: "%02x", $0) }.joined() + ".img"
    }
}

// MARK: - Who has which photo

/// Looks up profile photos by user ID, batching requests from a whole screen into one query.
/// Rows that only know a user ID (contacts, call history, the call screen) use this.
@MainActor
final class AvatarDirectory: ObservableObject {
    static let shared = AvatarDirectory()

    /// user ID (lowercased) -> photo reference; "" = looked up, no photo.
    @Published private(set) var photos: [String: String] = [:]
    private var fetchedAt: [String: Date] = [:]
    private var queued = Set<String>()
    private var flushScheduled = false
    private let maxAge: TimeInterval = 10 * 60

    func photo(for userId: String?) -> String? {
        guard let key = userId?.lowercased(), let value = photos[key], !value.isEmpty else { return nil }
        return value
    }

    /// Asks for a user's photo if we don't have a recent answer.
    func request(_ userId: String?) {
        guard let key = userId?.lowercased(), !key.isEmpty else { return }
        if let at = fetchedAt[key], Date().timeIntervalSince(at) < maxAge { return }
        queued.insert(key)
        guard !flushScheduled else { return }
        flushScheduled = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            await self.flush()
        }
    }

    /// Records a photo we already know (e.g. my own right after uploading it).
    func set(_ reference: String?, for userId: String) {
        let key = userId.lowercased()
        photos[key] = reference ?? ""
        fetchedAt[key] = Date()
    }

    private struct Row: Decodable {
        let id: String
        let photo_url: String?
    }

    private func flush() async {
        flushScheduled = false
        let ids = Array(queued)
        queued.removeAll()
        guard !ids.isEmpty else { return }
        ids.forEach { fetchedAt[$0] = Date() }       // don't ask again while this runs
        do {
            // Profile IDs are stored in more than one case, so ask for both.
            let variants = Array(Set(ids + ids.map { $0.uppercased() }))
            let response = try await SupabaseManager.client.from("profiles")
                .select("id, photo_url")
                .in("id", values: variants)
                .execute()
            let rows = try JSONDecoder().decode([Row].self, from: response.data)
            var found = Set<String>()
            for row in rows {
                let key = row.id.lowercased()
                photos[key] = row.photo_url ?? ""
                found.insert(key)
            }
            for id in ids where !found.contains(id) { photos[id] = "" }
        } catch {
            ids.forEach { fetchedAt[$0] = nil }       // try again next time it's shown
        }
    }
}

/// Avatar for a Let Talk user, looked up by user ID. Shows `fallbackURL` (if the screen
/// already has one) until the lookup answers, and the initials if there is no photo.
struct UserAvatar: View {
    let userId: String?
    let name: String
    var fallbackURL: String? = nil
    var size: CGFloat = 44
    @ObservedObject private var directory = AvatarDirectory.shared

    var body: some View {
        ProfileImageView(imageURL: directory.photo(for: userId) ?? fallbackURL,
                         placeholderText: Initials.from(name),
                         size: size)
            .onAppear { directory.request(userId) }
    }
}

// MARK: - Camera / library picker

/// The system picker for the camera or the photo library, with iOS's square crop.
struct SystemImagePicker: UIViewControllerRepresentable {
    let source: UIImagePickerController.SourceType
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(source) ? source : .photoLibrary
        if picker.sourceType == .camera {
            picker.cameraDevice = UIImagePickerController.isCameraDeviceAvailable(.front) ? .front : .rear
        }
        picker.allowsEditing = true          // square crop; the app shows it in a circle
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SystemImagePicker
        init(_ parent: SystemImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            parent.dismiss()
            if let image { parent.onPick(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

extension UIImage {
    /// Square, centre-cropped, at most `side` points, ready to upload as an avatar.
    func squareAvatar(side: CGFloat = 512) -> UIImage {
        let shortest = min(size.width, size.height)
        let crop = CGRect(x: (size.width - shortest) / 2, y: (size.height - shortest) / 2,
                          width: shortest, height: shortest)
        let target = min(side, shortest)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format).image { _ in
            let scale = target / shortest
            draw(in: CGRect(x: -crop.minX * scale, y: -crop.minY * scale,
                            width: size.width * scale, height: size.height * scale))
        }
    }
}

// MARK: - Ringing glow

/// Soft brand-colour rings that keep spreading out behind an avatar while a call rings.
struct RingingGlow: View {
    let active: Bool
    var color: Color = Brand.yellow
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(active ? 0.35 : 0))
                .blur(radius: 24)
                .scaleEffect(1.25)
            if !reduceMotion {
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(color.opacity(0.6), lineWidth: 2)
                        .scaleEffect(animate ? 1.7 : 1)
                        .opacity(animate ? 0 : 0.9)
                        .animation(
                            active
                                ? .easeOut(duration: 2.1).repeatForever(autoreverses: false).delay(Double(ring) * 0.7)
                                : .default,
                            value: animate)
                }
            }
        }
        .opacity(active ? 1 : 0)
        .animation(.easeInOut(duration: 0.4), value: active)
        .onAppear { animate = active }
        .onChange(of: active) { _, isActive in animate = isActive }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
