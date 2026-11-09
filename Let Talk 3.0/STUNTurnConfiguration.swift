import Foundation
import WebRTC

// MARK: - STUN/TURN Server Configuration
//
// STUN finds a direct path between two phones. When there is none (cellular carrier NAT, strict
// office Wi-Fi), media must be relayed through TURN. TURN credentials are short-lived and come from
// the `turn-credentials` Edge Function (Cloudflare Realtime TURN), never from the app bundle.
final class STUNTurnConfiguration {
    static let shared = STUNTurnConfiguration()

    /// Used when TURN credentials can't be fetched: calls still work on most home/office networks.
    /// (The old list had 16 servers, many long dead, which only slowed ICE gathering.)
    private let fallbackStunServers = [
        "stun:stun.cloudflare.com:3478",
        "stun:stun.l.google.com:19302",
        "stun:stun1.l.google.com:19302"
    ]

    private struct CachedServers {
        let servers: [RTCIceServer]
        let expiresAt: Date
    }

    private var cache: CachedServers?
    private let lock = NSLock()

    private init() {}

    /// Builds the configuration for a new call. Fetches TURN credentials (cached until shortly
    /// before they expire); if that fails, falls back to STUN only rather than blocking the call.
    func makeConfiguration() async -> RTCConfiguration {
        let config = RTCConfiguration()
        config.iceServers = await iceServers()
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        config.bundlePolicy = .maxBundle
        config.rtcpMuxPolicy = .require
        config.tcpCandidatePolicy = .enabled
        config.candidateNetworkPolicy = .all
        return config
    }

    private func iceServers() async -> [RTCIceServer] {
        if let cached = lock.withLock({ cache }), cached.expiresAt > Date() {
            return cached.servers
        }
        do {
            let response = try await Backend.turnCredentials()
            let servers = response.iceServers.compactMap { server -> RTCIceServer? in
                guard !server.urls.isEmpty else { return nil }
                return RTCIceServer(urlStrings: server.urls, username: server.username, credential: server.credential)
            }
            guard !servers.isEmpty else { return fallbackServers() }
            // Refresh 10 minutes before expiry so a call never starts with credentials about to lapse.
            let lifetime = max(Double(response.ttl) - 600, 60)
            lock.withLock { cache = CachedServers(servers: servers, expiresAt: Date().addingTimeInterval(lifetime)) }
            return servers
        } catch {
            debugLog("TURN credentials unavailable, using STUN only: \(error)")
            return fallbackServers()
        }
    }

    private func fallbackServers() -> [RTCIceServer] {
        [RTCIceServer(urlStrings: fallbackStunServers)]
    }
}
