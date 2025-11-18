import Foundation
import ARKit

/// Rough analogue of a Leap frame/tracking event.
/// A snapshot of both hands at a given moment.
public struct HandFrame: Sendable {
    /// Monotonically increasing ID (local to this process).
    public let id: Int

    /// Timestamp in seconds since 1970.
    public let timestamp: TimeInterval

    /// Left hand state, if tracked.
    public let leftHand: TrackedHand?

    /// Right hand state, if tracked.
    public let rightHand: TrackedHand?

    /// Convenience: all currently tracked hands as an array.
    public var hands: [TrackedHand] {
        [leftHand, rightHand].compactMap { $0 }
    }

    public init(
        id: Int,
        timestamp: TimeInterval,
        leftHand: TrackedHand?,
        rightHand: TrackedHand?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.leftHand = leftHand
        self.rightHand = rightHand
    }
}
