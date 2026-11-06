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

    struct DeleteResponse: Decodable { let deleted: Bool? }
    static func deleteAccount() async throws {
        let _: DeleteResponse = try await call("delete-account", body: Empty())
    }
}
