import Foundation
import CoreGraphics

public enum IdleDetector {
    /// Returns the number of seconds since the last system-wide user interaction (mouse/keyboard).
    public static func currentIdleSeconds() -> TimeInterval {
        // CGEventType(rawValue: ~0) queries all session input events
        let anyEvent = CGEventType(rawValue: ~0) ?? .null
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
    }

    /// Checks if the user has been inactive for longer than the specified threshold.
    public static func isUserIdle(thresholdSeconds: TimeInterval) -> Bool {
        return currentIdleSeconds() >= thresholdSeconds
    }
}
