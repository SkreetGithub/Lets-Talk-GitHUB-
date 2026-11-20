import Foundation
import CallKit
import PushKit
import AVFoundation
import Supabase

/// Native call UI (CallKit) + VoIP push (PushKit) so calls ring when the app is closed.
/// Server side: `supabase/functions/send-voip-push` (needs an APNs auth key, see REVIEW/SETUP notes).
final class CallKitManager: NSObject, ObservableObject {
    static let shared = CallKitManager()

    private let provider: CXProvider
    private let callController = CXCallController()
    private var voipRegistry: PKPushRegistry?
    /// CallKit UUID -> Supabase call id
    private var callIds: [UUID: (callId: String, isVideo: Bool)] = [:]
    private let tokenKey = "voipPushToken"

    private override init() {
        let config = CXProviderConfiguration()
        config.supportsVideo = true
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    // MARK: - PushKit

    func registerVoIP() {
        guard voipRegistry == nil else { return }
        let registry = PKPushRegistry(queue: .main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        voipRegistry = registry
    }

    /// Call after sign-in so the token is stored for the current user.
    func uploadPendingToken() {
        guard let token = UserDefaults.standard.string(forKey: tokenKey),
              let userId = AuthManager.shared.currentUserId else { return }
        Task {
            let row = PushTokenRow(user_id: userId, token: token, kind: "voip", updated_at: ISO8601DateFormatter().string(from: Date()))
            _ = try? await SupabaseManager.client.from("push_tokens").upsert(row).execute()
        }
    }

    private struct PushTokenRow: Encodable {
        let user_id: String
        let token: String
        let kind: String
        let updated_at: String
    }

    // MARK: - Reporting calls

    func reportIncomingCall(callId: String, callerName: String, isVideo: Bool, completion: ((Error?) -> Void)? = nil) {
        let uuid = UUID()
        callIds[uuid] = (callId, isVideo)
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.localizedCallerName = callerName
        update.hasVideo = isVideo
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if error != nil { self?.callIds[uuid] = nil }
            completion?(error)
            if error == nil { self?.stopRingingWhenCallerHangsUp(uuid: uuid, callId: callId) }
        }
    }

    /// While the iPhone's call screen is ringing, check the call every 2 s; if the caller hung
    /// up (or it timed out), stop ringing instead of ringing for a call that's gone.
    private func stopRingingWhenCallerHangsUp(uuid: UUID, callId: String) {
        Task { [weak self] in
            for _ in 0..<25 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, self.callIds[uuid] != nil else { return }
                // Answered on this phone: the call screen takes over.
                if WebRTCCallManager.shared.isInCall { return }
                guard let status = await SupabaseSignalingService.shared.fetchCallStatus(callId: callId) else { continue }
                switch status {
                case .ended, .missed, .rejected:
                    self.callIds[uuid] = nil
                    self.provider.reportCall(with: uuid, endedAt: nil, reason: .remoteEnded)
                    return
                default:
                    continue
                }
            }
        }
    }

    /// The call is over in the app (either side hung up, declined, missed or failed): close the
    /// iPhone's own call UI too. Before, a call answered from the lock screen stayed "active" on
    /// the iPhone (green bar / call screen) after hanging up, and an unanswered call kept ringing
    /// after the caller's side had already given up.
    func reportEnded(callId: String) {
        DispatchQueue.main.async {
            guard let entry = self.callIds.first(where: { $0.value.callId == callId }) else { return }
            self.callIds[entry.key] = nil
            self.provider.reportCall(with: entry.key, endedAt: nil, reason: .remoteEnded)
        }
    }

    /// Answer through CallKit when the iPhone is also showing this call (the banner at the top),
    /// so the banner closes and the iPhone knows the call was answered. Returns false if CallKit
    /// isn't showing it, so the caller answers in-app directly.
    func answerIfShowing(callId: String) -> Bool {
        guard let entry = callIds.first(where: { $0.value.callId == callId }) else { return false }
        callController.request(CXTransaction(action: CXAnswerCallAction(call: entry.key))) { error in
            if error != nil {
                // CallKit refused (e.g. the call already left it): answer in-app instead.
                Task { try? await WebRTCCallManager.shared.answerCall(callId: callId, isVideo: entry.value.isVideo) }
            }
        }
        return true
    }

    func endCall(callId: String) {
        guard let entry = callIds.first(where: { $0.value.callId == callId }) else { return }
        let action = CXEndCallAction(call: entry.key)
        callController.request(CXTransaction(action: action)) { _ in }
    }
}

// MARK: - PKPushRegistryDelegate

extension CallKitManager: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        uploadPendingToken()
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {
        // iOS requires every VoIP push to be reported to CallKit right away.
        let dict = payload.dictionaryPayload
        let callId = (dict["call_id"] as? String) ?? UUID().uuidString
        let name = (dict["caller_name"] as? String) ?? "Let Talk"
        let video = (dict["video"] as? Bool) ?? false
        reportIncomingCall(callId: callId, callerName: name, isVideo: video) { _ in completion() }
    }
}

// MARK: - CXProviderDelegate

extension CallKitManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        callIds.removeAll()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let entry = callIds[action.callUUID] else {
            action.fail()
            return
        }
        Task {
            do {
                try await WebRTCCallManager.shared.answerCall(callId: entry.callId, isVideo: entry.isVideo)
                action.fulfill()
            } catch {
                action.fail()
            }
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let entry = callIds[action.callUUID]
        callIds[action.callUUID] = nil
        Task {
            if WebRTCCallManager.shared.isInCall {
                await WebRTCCallManager.shared.endCall()
            } else if let entry {
                try? await SupabaseSignalingService.shared.rejectCall(callId: entry.callId)
            }
            action.fulfill()
        }
    }

    /// The mute button on the iPhone's own call screen (lock screen / Dynamic Island).
    /// It did nothing before; now it mutes the call and live translation like the in-app button.
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        WebRTCCallManager.shared.setMuted(action.isMuted)
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {}
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}
}
