import Foundation
import WebRTC

// MARK: - STUN/TURN Server Configuration
class STUNTurnConfiguration {
    static let shared = STUNTurnConfiguration()
    
    // Free STUN servers
    private let stunServers = [
        "stun:stun.l.google.com:19302",
        "stun:stun1.l.google.com:19302",
        "stun:stun2.l.google.com:19302",
        "stun:stun3.l.google.com:19302",
        "stun:stun4.l.google.com:19302",
        "stun:stun.ekiga.net",
        "stun:stun.ideasip.com",
        "stun:stun.schlund.de",
        "stun:stun.stunprotocol.org:3478",
        "stun:stun.voiparound.com",
        "stun:stun.voipbuster.com",
        "stun:stun.voipstunt.com",
        "stun:stun.counterpath.com",
        "stun:stun.1und1.de",
        "stun:stun.gmx.net",
        "stun:stun.internetcalls.com"
    ]
    
    // Production TURN servers (replace with your own)
    private let turnServers: [RTCIceServer] = [
        // Add your TURN server credentials here
        // RTCIceServer(
        //     urlStrings: ["turn:your-turn-server.com:3478"],
        //     username: "username",
        //     credential: "password"
        // )
    ]
    
    func getIceServers() -> [RTCIceServer] {
        var servers: [RTCIceServer] = []
        
        // Add STUN servers
        for stunUrl in stunServers {
            servers.append(RTCIceServer(urlStrings: [stunUrl]))
        }
        
        // Add TURN servers
        servers.append(contentsOf: turnServers)
        
        return servers
    }
    
    func getRTCConfiguration() -> RTCConfiguration {
        let config = RTCConfiguration()
        config.iceServers = getIceServers()
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        config.bundlePolicy = .maxBundle
        config.rtcpMuxPolicy = .require
        config.tcpCandidatePolicy = .enabled
        config.candidateNetworkPolicy = .all
        return config
    }
}
