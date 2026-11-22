import Foundation
import WebRTC

/// Shared utility functions for call-related operations
enum CallUtilities {
    
    // MARK: - Duration Formatting
    
    /// Format time duration as MM:SS string
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Format time duration from seconds integer as MM:SS or HH:MM:SS string
    static func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    // MARK: - ICE Connection State
    
    /// Convert RTCIceConnectionState to readable string
    static func iceConnectionStateString(_ state: RTCIceConnectionState) -> String {
        switch state {
        case .new: return "new"
        case .checking: return "checking"
        case .connected: return "connected"
        case .completed: return "completed"
        case .failed: return "failed"
        case .disconnected: return "disconnected"
        case .closed: return "closed"
        @unknown default: return "unknown(\(state.rawValue))"
        }
    }
    
    // MARK: - Call Timer
    
    /// Create and start a call duration timer
    static func createCallTimer(updateHandler: @escaping (TimeInterval) -> Void) -> Timer {
        var duration: TimeInterval = 0
        return Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            duration += 1
            updateHandler(duration)
        }
    }
}

