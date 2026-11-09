import Foundation
import Supabase
import WebRTC

// Call signaling over Supabase (calls + signaling tables / realtime).
final class SupabaseSignalingService: ObservableObject {
    static let shared = SupabaseSignalingService()

    private let client = SupabaseManager.client

    // Weak multi-cast delegate list. Only WebRTCCallManager registers now (WebRTCService no longer does).
    private let delegates = NSHashTable<AnyObject>.weakObjects()

    // Polling runs in Tasks, not Timers: Timer.scheduledTimer only fires on a thread with a
    // running run loop, and these were started from async (background) code, so after the first
    // poll they never fired again. Offers, answers and ICE candidates were never received.
    private var callPollTasks: [String: Task<Void, Never>] = [:]
    private var messagePollTasks: [String: Task<Void, Never>] = [:]
    private var processedMessageIdsByCall: [String: Set<String>] = [:]
    private var incomingCallsTask: Task<Void, Never>?
    private var announcedIncomingCallIds: Set<String> = []
    private let lock = NSLock()

    /// Incoming calls older than this are treated as stale (e.g. the caller's app crashed).
    private let incomingCallMaxAge: TimeInterval = 45

    // .iso8601 rejects Supabase's fractional seconds ("...04.174123+00:00"), so rows failed to decode.
    private let decoder: JSONDecoder = PostgresDate.decoder

    private init() {}

    deinit {
        removeAllListeners()
    }

    // MARK: - Delegate Management

    func addDelegate(_ delegate: SupabaseSignalingDelegate) {
        delegates.add(delegate)
    }

    func removeDelegate(_ delegate: SupabaseSignalingDelegate) {
        delegates.remove(delegate)
    }

    private func notify(_ block: (SupabaseSignalingDelegate) -> Void) {
        for obj in delegates.allObjects {
            guard let d = obj as? SupabaseSignalingDelegate else { continue }
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

        // Create encodable struct for insertion
        let callInsert = CallInsert(
            id: call.id,
            callerId: call.callerId,
            calleeId: call.calleeId,
            isVideo: call.isVideo,
            status: call.status.rawValue,
            createdAt: ISO8601DateFormatter().string(from: call.createdAt),
            participants: call.participants,
            answeredAt: call.answeredAt.map { ISO8601DateFormatter().string(from: $0) },
            endedAt: call.endedAt.map { ISO8601DateFormatter().string(from: $0) },
            rejectedAt: call.rejectedAt.map { ISO8601DateFormatter().string(from: $0) }
        )
        
        _ = try await client.from("calls")
            .insert(callInsert)
            .execute()

        listenForCallUpdates(callId: callId)

        // Ring the callee even if their app is closed (PushKit VoIP via Edge Function). Best effort.
        let callerName = AuthManager.shared.currentUser?.name ?? "Let Talk"
        Task {
            try? await Backend.sendVoIPPush(calleeId: targetUserId, callerName: callerName, callId: callId, video: isVideo)
        }
        return callId
    }

    func answerCall(callId: String, isVideo: Bool) async throws {
        guard AuthManager.shared.currentUserId != nil else {
            throw SignalingError.userNotAuthenticated
        }

        // Create encodable struct for update
        let updateData = CallUpdate(
            status: CallStatus.answered.rawValue,
            answeredAt: ISO8601DateFormatter().string(from: Date()),
            isVideo: isVideo
        )
        
        _ = try await client.from("calls")
            .update(updateData)
            .eq("id", value: callId)
            .execute()

        listenForCallUpdates(callId: callId)
    }

    func endCall(callId: String) async throws {
        let updateData = CallUpdate(
            status: CallStatus.ended.rawValue,
            endedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        _ = try await client.from("calls")
            .update(updateData)
            .eq("id", value: callId)
            .execute()

        stopListening(callId: callId)
    }

    func rejectCall(callId: String) async throws {
        let updateData = CallUpdate(
            status: CallStatus.rejected.rawValue,
            rejectedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        _ = try await client.from("calls")
            .update(updateData)
            .eq("id", value: callId)
            .execute()

        stopListening(callId: callId)
    }

    /// Marks an unanswered outgoing call as missed (stops the other phone ringing).
    func markMissed(callId: String) async throws {
        _ = try await client.from("calls")
            .update(CallUpdate(status: CallStatus.missed.rawValue, endedAt: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: callId)
            .eq("status", value: CallStatus.initiated.rawValue)
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
        let row = SignalInsert(
            id: UUID().uuidString,
            callId: callId,
            type: SignalingMessageType.iceCandidate.rawValue,
            senderId: AuthManager.shared.currentUserId ?? "",
            candidate: candidate.sdp,
            sdpMLineIndex: candidate.sdpMLineIndex,
            sdpMid: candidate.sdpMid ?? "",
            timestamp: ISO8601DateFormatter().string(from: Date())
        )

        _ = try await client.from("call_signals")
            .insert(row)
            .execute()
    }

    private func insertSignal(callId: String, type: SignalingMessageType, sdp: String) async throws {
        let row = SignalInsert(
            id: UUID().uuidString,
            callId: callId,
            type: type.rawValue,
            senderId: AuthManager.shared.currentUserId ?? "",
            sdp: sdp,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )

        _ = try await client.from("call_signals")
            .insert(row)
            .execute()
    }

    // MARK: - Listening

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    /// Runs `body` now and then every `seconds` until cancelled. Polls never overlap.
    private func pollingTask(every seconds: Double, _ body: @escaping () async -> Void) -> Task<Void, Never> {
        Task.detached(priority: .userInitiated) {
            while !Task.isCancelled {
                await body()
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
    }

    func startListeningForIncomingCalls() {
        let task = pollingTask(every: 1.5) { [weak self] in
            await self?.pollIncomingCalls()
        }
        withLock {
            incomingCallsTask?.cancel()
            incomingCallsTask = task
        }
    }

    private func pollIncomingCalls() async {
        guard let currentUserId = AuthManager.shared.currentUserId else { return }
        let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-incomingCallMaxAge))

        do {
            let response = try await client.from("calls")
                .select()
                .eq("callee_id", value: currentUserId)
                .eq("status", value: CallStatus.initiated.rawValue)
                .gte("created_at", value: cutoff)          // ignore stale rows that would ring forever
                .order("created_at", ascending: false)
                .limit(5)
                .execute()

            let calls = try decoder.decode([CallRowData].self, from: response.data)

            for call in calls {
                // Announce each call once (it used to be re-announced every 1.5 s).
                let isNew = withLock { announcedIncomingCallIds.insert(call.id).inserted }
                guard isNew else { continue }
                notify { $0.supabaseSignaling(self, didReceiveIncomingCall: call.asCall) }
            }
        } catch {
            debugLog("Incoming-call poll failed: \(error)")
        }
    }

    /// Watches a call row (answered / rejected / ended / missed). Used by the caller, and by the
    /// callee while ringing so it stops ringing if the caller hangs up first.
    func watchCall(callId: String) {
        listenForCallUpdates(callId: callId)
    }

    private func listenForCallUpdates(callId: String) {
        let task = pollingTask(every: 1.0) { [weak self] in
            await self?.pollCall(callId: callId)
        }
        withLock {
            callPollTasks[callId]?.cancel()
            callPollTasks[callId] = task
        }
    }

    private func pollCall(callId: String) async {
        do {
            let response = try await client.from("calls")
                .select()
                .eq("id", value: callId)
                .single()
                .execute()

            let row = try decoder.decode(CallRowData.self, from: response.data)
            notify { $0.supabaseSignaling(self, didReceiveCallUpdate: row.asCall) }
        } catch {
            debugLog("Call poll failed: \(error)")
        }
    }

    func listenForSignalingMessages(callId: String) {
        let task = pollingTask(every: 0.5) { [weak self] in
            await self?.pollSignals(callId: callId)
        }
        withLock {
            if processedMessageIdsByCall[callId] == nil { processedMessageIdsByCall[callId] = [] }
            messagePollTasks[callId]?.cancel()
            messagePollTasks[callId] = task
        }
    }

    private func pollSignals(callId: String) async {
        do {
            let response = try await client.from("call_signals")
                .select()
                .eq("call_id", value: callId)
                .order("timestamp", ascending: true)
                .limit(500)
                .execute()

            let rows = try decoder.decode([SignalRow].self, from: response.data)
            let me = AuthManager.shared.currentUserId

            let fresh: [SignalRow] = withLock {
                var processed = processedMessageIdsByCall[callId] ?? []
                var out: [SignalRow] = []
                for row in rows where !processed.contains(row.id) {
                    processed.insert(row.id)
                    if row.senderId != me { out.append(row) }   // only the other side's messages
                }
                processedMessageIdsByCall[callId] = processed
                return out
            }

            // Offers/answers first, so ICE candidates in the same batch have a description to attach to.
            let ordered = fresh.filter { $0.type != SignalingMessageType.iceCandidate.rawValue }
                + fresh.filter { $0.type == SignalingMessageType.iceCandidate.rawValue }
            for row in ordered {
                notify { $0.supabaseSignaling(self, didReceiveSignalingMessage: row.asSignalingMessage) }
            }
        } catch {
            debugLog("Signal poll failed: \(error)")
        }
    }

    func stopListening(callId: String) {
        withLock {
            callPollTasks.removeValue(forKey: callId)?.cancel()
            messagePollTasks.removeValue(forKey: callId)?.cancel()
            processedMessageIdsByCall.removeValue(forKey: callId)
        }
    }

    private func removeAllListeners() {
        withLock {
            incomingCallsTask?.cancel()
            incomingCallsTask = nil
            callPollTasks.values.forEach { $0.cancel() }
            callPollTasks.removeAll()
            messagePollTasks.values.forEach { $0.cancel() }
            messagePollTasks.removeAll()
            processedMessageIdsByCall.removeAll()
        }
    }
}

// MARK: - Delegate

protocol SupabaseSignalingDelegate: AnyObject {
    func supabaseSignaling(_ service: SupabaseSignalingService, didReceiveCallUpdate call: Call)
    func supabaseSignaling(_ service: SupabaseSignalingService, didReceiveIncomingCall call: Call)
    func supabaseSignaling(_ service: SupabaseSignalingService, didReceiveSignalingMessage message: SignalingMessage)
    func supabaseSignaling(_ service: SupabaseSignalingService, didReceiveError error: Error)
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

// MARK: - Supabase Insert/Update Structs

private struct CallInsert: Codable {
    let id: String
    let callerId: String
    let calleeId: String
    let isVideo: Bool
    let status: String
    let createdAt: String
    let participants: [String]
    let answeredAt: String?
    let endedAt: String?
    let rejectedAt: String?
    
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
}

private struct CallUpdate: Codable {
    let status: String?
    let answeredAt: String?
    let endedAt: String?
    let rejectedAt: String?
    let isVideo: Bool?
    
    enum CodingKeys: String, CodingKey {
        case status
        case answeredAt = "answered_at"
        case endedAt = "ended_at"
        case rejectedAt = "rejected_at"
        case isVideo = "is_video"
    }
    
    init(status: String? = nil, answeredAt: String? = nil, endedAt: String? = nil, rejectedAt: String? = nil, isVideo: Bool? = nil) {
        self.status = status
        self.answeredAt = answeredAt
        self.endedAt = endedAt
        self.rejectedAt = rejectedAt
        self.isVideo = isVideo
    }
}

private struct SignalInsert: Codable {
    let id: String
    let callId: String
    let type: String
    let senderId: String
    let sdp: String?
    let candidate: String?
    let sdpMLineIndex: Int32?
    let sdpMid: String?
    let timestamp: String
    
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
    
    init(id: String, callId: String, type: String, senderId: String, sdp: String? = nil, candidate: String? = nil, sdpMLineIndex: Int32? = nil, sdpMid: String? = nil, timestamp: String) {
        self.id = id
        self.callId = callId
        self.type = type
        self.senderId = senderId
        self.sdp = sdp
        self.candidate = candidate
        self.sdpMLineIndex = sdpMLineIndex
        self.sdpMid = sdpMid
        self.timestamp = timestamp
    }
}

// MARK: - Supabase Row Decoding

private struct CallRowData: Codable {
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
