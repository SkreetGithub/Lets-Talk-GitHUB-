import Foundation
import Supabase
import WebRTC

// NOTE: Firebase has been removed. This class name is kept to avoid rewriting
// large parts of the UI/WebRTC stack, but the implementation now uses Supabase.
final class FirebaseSignalingService: ObservableObject {
    static let shared = FirebaseSignalingService()

    private let client = SupabaseManager.client

    // Weak multi-cast delegate list so both WebRTC managers can listen.
    private let delegates = NSHashTable<AnyObject>.weakObjects()

    private var callPollTimers: [String: Timer] = [:]
    private var messagePollTimers: [String: Timer] = [:]
    private var processedMessageIdsByCall: [String: Set<String>] = [:]
    private var incomingCallsTimer: Timer?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {}

    deinit {
        removeAllListeners()
    }

    // MARK: - Delegate Management

    func addDelegate(_ delegate: FirebaseSignalingDelegate) {
        delegates.add(delegate)
    }

    func removeDelegate(_ delegate: FirebaseSignalingDelegate) {
        delegates.remove(delegate)
    }

    private func notify(_ block: (FirebaseSignalingDelegate) -> Void) {
        for obj in delegates.allObjects {
            guard let d = obj as? FirebaseSignalingDelegate else { continue }
            block(d)
        }
    }

    // MARK: - Call Management

    func createCall(to targetUserId: String, isVideo: Bool) async throws -> String {
        guard let currentUserId = AuthManager.shared.currentUserId else {
            throw SignalingError.userNotAuthenticated
        }

        let callId = UUID().uuidString
        let call = Call(
            id: callId,
            callerId: currentUserId,
            calleeId: targetUserId,
            isVideo: isVideo,
            status: .initiated,
            createdAt: Date(),
            participants: [currentUserId, targetUserId]
        )

        _ = try await client.from("calls")
            .insert(call.toDictionary())
            .execute()

        listenForCallUpdates(callId: callId)
        return callId
    }

    func answerCall(callId: String, isVideo: Bool) async throws {
        guard AuthManager.shared.currentUserId != nil else {
            throw SignalingError.userNotAuthenticated
        }

        _ = try await client.from("calls")
            .update([
                "status": CallStatus.answered.rawValue,
                "answered_at": ISO8601DateFormatter().string(from: Date()),
                "is_video": isVideo
            ])
            .eq("id", value: callId)
            .execute()

        listenForCallUpdates(callId: callId)
    }

    func endCall(callId: String) async throws {
        _ = try await client.from("calls")
            .update([
                "status": CallStatus.ended.rawValue,
                "ended_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: callId)
            .execute()

        stopListening(callId: callId)
    }

    func rejectCall(callId: String) async throws {
        _ = try await client.from("calls")
            .update([
                "status": CallStatus.rejected.rawValue,
                "rejected_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: callId)
            .execute()

        stopListening(callId: callId)
    }

    // MARK: - Signaling Messages

    func sendOffer(callId: String, offer: RTCSessionDescription) async throws {
        try await insertSignal(callId: callId, type: .offer, sdp: offer.sdp)
    }

    func sendAnswer(callId: String, answer: RTCSessionDescription) async throws {
        try await insertSignal(callId: callId, type: .answer, sdp: answer.sdp)
    }

    func sendIceCandidate(callId: String, candidate: RTCIceCandidate) async throws {
        let row: [String: Any] = [
            "id": UUID().uuidString,
            "call_id": callId,
            "type": SignalingMessageType.iceCandidate.rawValue,
            "sender_id": AuthManager.shared.currentUserId ?? "",
            "candidate": candidate.sdp,
            "sdp_mline_index": candidate.sdpMLineIndex,
            "sdp_mid": candidate.sdpMid ?? "",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        _ = try await client.from("call_signals")
            .insert(row)
            .execute()
    }

    private func insertSignal(callId: String, type: SignalingMessageType, sdp: String) async throws {
        let row: [String: Any] = [
            "id": UUID().uuidString,
            "call_id": callId,
            "type": type.rawValue,
            "sender_id": AuthManager.shared.currentUserId ?? "",
            "sdp": sdp,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        _ = try await client.from("call_signals")
            .insert(row)
            .execute()
    }

    // MARK: - Listening

    func startListeningForIncomingCalls() {
        incomingCallsTimer?.invalidate()

        incomingCallsTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.pollIncomingCalls()
            }
        }

        // Fire immediately.
        Task { await pollIncomingCalls() }
    }

    private func pollIncomingCalls() async {
        guard let currentUserId = AuthManager.shared.currentUserId else { return }

        do {
            let response = try await client.from("calls")
                .select()
                .eq("callee_id", value: currentUserId)
                .eq("status", value: CallStatus.initiated.rawValue)
                .order("created_at", ascending: false)
                .limit(5)
                .execute()

            let calls = try decoder.decode([CallRow].self, from: response.data)

            for call in calls {
                notify { $0.firebaseSignaling(self, didReceiveIncomingCall: call.asCall) }
            }
        } catch {
            notify { $0.firebaseSignaling(self, didReceiveError: error) }
        }
    }

    private func listenForCallUpdates(callId: String) {
        callPollTimers[callId]?.invalidate()

        callPollTimers[callId] = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.pollCall(callId: callId)
            }
        }

        Task { await pollCall(callId: callId) }
    }

    private func pollCall(callId: String) async {
        do {
            let response = try await client.from("calls")
                .select()
                .eq("id", value: callId)
                .single()
                .execute()

            let row = try decoder.decode(CallRow.self, from: response.data)
            notify { $0.firebaseSignaling(self, didReceiveCallUpdate: row.asCall) }
        } catch {
            notify { $0.firebaseSignaling(self, didReceiveError: error) }
        }
    }

    func listenForSignalingMessages(callId: String) {
        messagePollTimers[callId]?.invalidate()

        if processedMessageIdsByCall[callId] == nil {
            processedMessageIdsByCall[callId] = []
        }

        messagePollTimers[callId] = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.pollSignals(callId: callId)
            }
        }

        Task { await pollSignals(callId: callId) }
    }

    private func pollSignals(callId: String) async {
        do {
            let response = try await client.from("call_signals")
                .select()
                .eq("call_id", value: callId)
                .order("timestamp", ascending: true)
                .limit(200)
                .execute()

            let rows = try decoder.decode([SignalRow].self, from: response.data)

            var processed = processedMessageIdsByCall[callId] ?? []

            for row in rows {
                if processed.contains(row.id) { continue }
                processed.insert(row.id)

                // Only process messages from other users
                if row.senderId == AuthManager.shared.currentUserId {
                    continue
                }

                notify { $0.firebaseSignaling(self, didReceiveSignalingMessage: row.asSignalingMessage) }
            }

            processedMessageIdsByCall[callId] = processed
        } catch {
            notify { $0.firebaseSignaling(self, didReceiveError: error) }
        }
    }

    func stopListening(callId: String) {
        callPollTimers[callId]?.invalidate()
        callPollTimers.removeValue(forKey: callId)

        messagePollTimers[callId]?.invalidate()
        messagePollTimers.removeValue(forKey: callId)

        processedMessageIdsByCall.removeValue(forKey: callId)
    }

    private func removeAllListeners() {
        incomingCallsTimer?.invalidate()
        incomingCallsTimer = nil

        callPollTimers.values.forEach { $0.invalidate() }
        callPollTimers.removeAll()

        messagePollTimers.values.forEach { $0.invalidate() }
        messagePollTimers.removeAll()

        processedMessageIdsByCall.removeAll()
    }
}

// MARK: - Delegate

protocol FirebaseSignalingDelegate: AnyObject {
    func firebaseSignaling(_ service: FirebaseSignalingService, didReceiveCallUpdate call: Call)
    func firebaseSignaling(_ service: FirebaseSignalingService, didReceiveIncomingCall call: Call)
    func firebaseSignaling(_ service: FirebaseSignalingService, didReceiveSignalingMessage message: SignalingMessage)
    func firebaseSignaling(_ service: FirebaseSignalingService, didReceiveError error: Error)
}

// MARK: - Data Models

struct Call: Codable {
    let id: String
    let callerId: String
    let calleeId: String
    let isVideo: Bool
    let status: CallStatus
    let createdAt: Date
    let participants: [String]
    var answeredAt: Date?
    var endedAt: Date?
    var rejectedAt: Date?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "caller_id": callerId,
            "callee_id": calleeId,
            "is_video": isVideo,
            "status": status.rawValue,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "participants": participants
        ]

        if let answeredAt { dict["answered_at"] = ISO8601DateFormatter().string(from: answeredAt) }
        if let endedAt { dict["ended_at"] = ISO8601DateFormatter().string(from: endedAt) }
        if let rejectedAt { dict["rejected_at"] = ISO8601DateFormatter().string(from: rejectedAt) }

        return dict
    }
}

struct SignalingMessage: Codable {
    let id: String
    let callId: String
    let type: SignalingMessageType
    let senderId: String
    let sdp: String?
    let candidate: String?
    let sdpMLineIndex: Int32?
    let sdpMid: String?
    let timestamp: Date
}

enum CallStatus: String, Codable, CaseIterable {
    case initiated = "initiated"
    case ringing = "ringing"
    case answered = "answered"
    case ended = "ended"
    case rejected = "rejected"
    case missed = "missed"
}

enum SignalingMessageType: String, Codable, CaseIterable {
    case offer = "offer"
    case answer = "answer"
    case iceCandidate = "iceCandidate"
    case callEnd = "callEnd"
}

enum SignalingError: Error, LocalizedError {
    case userNotAuthenticated
    case callNotFound
    case invalidSignalingData
    case networkError

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated: return "User not authenticated"
        case .callNotFound: return "Call not found"
        case .invalidSignalingData: return "Invalid signaling data"
        case .networkError: return "Network error occurred"
        }
    }
}

// MARK: - Supabase Row Decoding

private struct CallRow: Codable {
    let id: String
    let callerId: String
    let calleeId: String
    let isVideo: Bool
    let status: String
    let createdAt: Date
    let participants: [String]
    let answeredAt: Date?
    let endedAt: Date?
    let rejectedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case callerId = "caller_id"
        case calleeId = "callee_id"
        case isVideo = "is_video"
        case status
        case createdAt = "created_at"
        case participants
        case answeredAt = "answered_at"
        case endedAt = "ended_at"
        case rejectedAt = "rejected_at"
    }

    var asCall: Call {
        Call(
            id: id,
            callerId: callerId,
            calleeId: calleeId,
            isVideo: isVideo,
            status: CallStatus(rawValue: status) ?? .initiated,
            createdAt: createdAt,
            participants: participants,
            answeredAt: answeredAt,
            endedAt: endedAt,
            rejectedAt: rejectedAt
        )
    }
}

private struct SignalRow: Codable {
    let id: String
    let callId: String
    let type: String
    let senderId: String
    let sdp: String?
    let candidate: String?
    let sdpMLineIndex: Int32?
    let sdpMid: String?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id
        case callId = "call_id"
        case type
        case senderId = "sender_id"
        case sdp
        case candidate
        case sdpMLineIndex = "sdp_mline_index"
        case sdpMid = "sdp_mid"
        case timestamp
    }

    var asSignalingMessage: SignalingMessage {
        SignalingMessage(
            id: id,
            callId: callId,
            type: SignalingMessageType(rawValue: type) ?? .offer,
            senderId: senderId,
            sdp: sdp,
            candidate: candidate,
            sdpMLineIndex: sdpMLineIndex,
            sdpMid: sdpMid,
            timestamp: timestamp
        )
    }
}
