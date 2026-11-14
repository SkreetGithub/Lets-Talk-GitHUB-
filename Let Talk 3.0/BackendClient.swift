import Foundation
import Supabase

/// Calls Supabase Edge Functions with the signed-in user's JWT.
/// Third-party API keys (Google Translate, OpenAI) live ONLY in the Edge Functions' secrets.
enum BackendError: LocalizedError {
    case notSignedIn
    case http(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Please sign in again."
        case .http(let code): return "The server returned an error (\(code))."
        case .invalidResponse: return "The server sent an unexpected response."
        }
    }
}

enum Backend {
    struct Empty: Encodable {}

    static func call<Req: Encodable, Res: Decodable>(_ function: String, body: Req, as: Res.Type = Res.self) async throws -> Res {
        let session: Session
        do {
            session = try await SupabaseManager.client.auth.session
        } catch {
            throw BackendError.notSignedIn
        }
        let url = Config.supabaseURL.appendingPathComponent("functions/v1/\(function)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw BackendError.http(http.statusCode) }
        do {
            return try JSONDecoder().decode(Res.self, from: data)
        } catch {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Typed helpers

    struct TranslateRequest: Encodable {
        let text: String
        let source: String?
        let target: String
        let provider: String?
    }
    struct TranslateResponse: Decodable {
        let translatedText: String
        let detectedLanguage: String?
    }
    static func translate(text: String, source: String?, target: String, provider: String? = nil) async throws -> TranslateResponse {
        try await call("translate", body: TranslateRequest(text: text, source: source, target: target, provider: provider))
    }

    // Translated speech (Google WaveNet via the `speak` function).
    struct VoiceSlot: Decodable, Identifiable, Hashable {
        let id: String          // "male-1" … "female-8"
        let gender: String
        let voice: String       // Google voice name, e.g. "en-US-Wavenet-D"
        let pitch: Double
        let rate: Double
    }
    struct VoicesRequest: Encodable { let action = "voices"; let language: String }
    struct VoicesResponse: Decodable { let language: String; let voices: [VoiceSlot] }
    static func voices(language: String) async throws -> VoicesResponse {
        try await call("speak", body: VoicesRequest(language: language))
    }

    struct SpeakRequest: Encodable {
        let action = "speak"
        let voice_id: String
        let text: String
        let language: String
    }
    struct SpeakResponse: Decodable { let audio: String; let voice: String? }
    /// MP3 audio of `text` spoken in `language` with voice `voiceId`.
    static func speak(text: String, voiceId: String, language: String) async throws -> Data {
        let response: SpeakResponse = try await call("speak", body: SpeakRequest(voice_id: voiceId, text: text, language: language))
        guard let audio = Data(base64Encoded: response.audio), !audio.isEmpty else { throw BackendError.invalidResponse }
        return audio
    }

    struct MessagePushRequest: Encodable { let message_id: String }
    struct MessagePushResponse: Decodable { let sent: Bool?; let reason: String? }
    /// Asks the server to notify the receiver of a message I just sent (in their language).
    static func sendMessagePush(messageId: String) async throws {
        let _: MessagePushResponse = try await call("send-message-push", body: MessagePushRequest(message_id: messageId))
    }

    // Contact sync: SHA-256 hashes of address-book numbers -> which are Let Talk users.
    struct ContactMatch: Decodable, Hashable {
        let hash: String
        let userId: String
        let name: String?
        enum CodingKeys: String, CodingKey { case hash, userId = "user_id", name }
    }
    struct MatchContactsRequest: Encodable { let hashes: [String] }
    struct MatchContactsResponse: Decodable { let matches: [ContactMatch] }
    static func matchContacts(hashes: [String]) async throws -> [ContactMatch] {
        let response: MatchContactsResponse = try await call("match-contacts", body: MatchContactsRequest(hashes: hashes))
        return response.matches
    }

    struct DetectRequest: Encodable { let text: String }
    struct DetectResponse: Decodable { let language: String?; let confidence: Double? }
    static func detectLanguage(_ text: String) async throws -> DetectResponse {
        try await call("detect-language", body: DetectRequest(text: text))
    }

    struct VoIPPushRequest: Encodable {
        let callee_id: String
        let caller_name: String
        let call_id: String
        let video: Bool
    }
    struct VoIPPushResponse: Decodable { let sent: Bool? }
    static func sendVoIPPush(calleeId: String, callerName: String, callId: String, video: Bool) async throws {
        let _: VoIPPushResponse = try await call("send-voip-push", body: VoIPPushRequest(callee_id: calleeId, caller_name: callerName, call_id: callId, video: video))
    }

    struct IceServer: Decodable {
        let urls: [String]
        let username: String?
        let credential: String?

        private enum CodingKeys: String, CodingKey { case urls, username, credential }

        // Cloudflare may send "urls" as a single string or an array.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let many = try? c.decode([String].self, forKey: .urls) {
                urls = many
            } else {
                urls = [try c.decode(String.self, forKey: .urls)]
            }
            username = try c.decodeIfPresent(String.self, forKey: .username)
            credential = try c.decodeIfPresent(String.self, forKey: .credential)
        }
    }
    struct TurnCredentialsResponse: Decodable {
        let iceServers: [IceServer]
        let ttl: Int
    }
    /// Short-lived Cloudflare TURN credentials for the signed-in user.
    static func turnCredentials() async throws -> TurnCredentialsResponse {
        try await call("turn-credentials", body: Empty())
    }

    struct DeleteResponse: Decodable { let deleted: Bool? }
    static func deleteAccount() async throws {
        let _: DeleteResponse = try await call("delete-account", body: Empty())
    }
}
