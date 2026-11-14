import Foundation
import Combine

/// Translates incoming chat messages into MY language, on my phone, when the chat is open.
///
/// The database keeps only what the sender typed (plus the sender's language in
/// `metadata["lang"]`). Each receiver translates into their own language, so the same message
/// reads correctly for everyone, and changing your language re-translates old messages too.
/// Results are cached on the device so a message is translated once, not on every refresh.
@MainActor
final class MessageTranslator: ObservableObject {
    static let shared = MessageTranslator()

    struct Entry: Codable {
        let language: String     // the language it was translated into
        let text: String?        // nil = already in that language, nothing to show
        let source: String?      // the sender's language, if known
    }

    @Published private(set) var entries: [String: Entry] = [:]
    private var inFlight = Set<String>()
    private var askedForConsent = false
    private let maxCached = 3000

    private var storeURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("message-translations.json")
    }

    /// The language messages are translated into (Settings → Language).
    var myLanguage: String { SettingsManager.shared.settings.language }

    private init() {
        if let data = try? Data(contentsOf: storeURL),
           let saved = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = saved
        }
    }

    /// The translation to show for `message`, or nil if none is needed (or it isn't ready yet).
    func translation(for message: Message) -> String? {
        guard let entry = entries[message.id], entry.language == myLanguage else { return nil }
        return entry.text
    }

    /// Display name of the language the sender wrote in, e.g. "Spanish".
    func sourceLanguageName(for message: Message) -> String? {
        let code = entries[message.id]?.source ?? message.metadata?["lang"]
        guard let code else { return nil }
        let base = String(code.prefix(2))
        return LiveLanguage.named(code: base)?.name
            ?? Locale.current.localizedString(forLanguageCode: base)
    }

    /// Translates any incoming text messages that aren't translated into my language yet.
    func translateIncoming(_ messages: [Message], myUserId: String?) {
        // Settings › Auto-translate off: show messages exactly as they were sent.
        guard SettingsManager.shared.settings.translation.autoTranslate else { return }
        let target = myLanguage
        let pending = messages.filter { message in
            message.type == .text
                && message.senderId != myUserId
                && !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && entries[message.id]?.language != target
                && !inFlight.contains(message.id)
        }
        guard !pending.isEmpty else { return }

        var toTranslate: [Message] = []
        for message in pending {
            if let source = message.metadata?["lang"], source == target {
                // The sender wrote in my language: nothing to translate, no provider call.
                entries[message.id] = Entry(language: target, text: nil, source: source)
            } else {
                toTranslate.append(message)
            }
        }
        guard !toTranslate.isEmpty else { save(); return }

        // Translation sends the text to Google/OpenAI: only after the user has agreed. Ask once
        // per launch; if they say no, messages simply stay in the sender's language.
        guard AIConsent.shared.hasConsented else {
            if !askedForConsent {
                askedForConsent = true
                AIConsent.shared.requireConsent()
            }
            return
        }

        toTranslate.forEach { inFlight.insert($0.id) }
        Task {
            // Newest first, so the message you're looking at is translated first.
            for message in toTranslate.reversed() {
                let source = message.metadata?["lang"]
                do {
                    let response = try await Backend.translate(text: message.content, source: source, target: target)
                    let translated = response.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let detected = response.detectedLanguage ?? source
                    let sameLanguage = translated.isEmpty
                        || translated == message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                        || (detected.map { $0.hasPrefix(target) } ?? false)
                    entries[message.id] = Entry(language: target, text: sameLanguage ? nil : translated, source: detected)
                } catch {
                    // Leave it untranslated; the next refresh of the chat tries again.
                }
                inFlight.remove(message.id)
            }
            save()
        }
    }

    private func save() {
        if entries.count > maxCached {
            // Drop an arbitrary overflow; a dropped message is simply translated again if reopened.
            for key in entries.keys.prefix(entries.count - maxCached) { entries[key] = nil }
        }
        let snapshot = entries
        let url = storeURL
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}
