import Foundation
import ARKit
import Observation

/// Owns an ARKitSession + HandTrackingProvider lifecycle and exposes
/// a cached "latest frame" plus a callback.
///
/// IMPORTANT: This version creates a fresh ARKitSession and
/// HandTrackingProvider every time `run()` is called, so you can
/// safely open/close immersive spaces without hitting the
/// "re-run a stopped data provider" exception.

@MainActor
@Observable
public final class VisionHandClient {

    public private(set) var latestFrame: HandFrame?
    public private(set) var latestFrameID: Int = 0   // for SwiftUI onChange
    public var onFrame: ((HandFrame) -> Void)?

    private var isRunning = false
    private var publishScheduled = false

    public enum HandTrackingError: Error {
        case notSupported
    }

    public init() {}

    /// Start hand tracking and enter the main update loop.
    ///
    /// Call this from a SwiftUI `.task` or your own Task.
    /// The loop ends when the surrounding Task is cancelled
    /// or when ARKit finishes the anchorUpdates stream.
    public func run() async throws {
        guard HandTrackingProvider.isSupported else {
            throw HandTrackingError.notSupported
        }

        // Prevent accidental double-start on the same instance.
        if isRunning {
            return
        }

        isRunning = true
        defer { isRunning = false }

        // IMPORTANT CHANGE:
        // Create new session + provider for each run.
        let session = ARKitSession()
        let provider = HandTrackingProvider()

        try await session.run([provider])
        defer { session.stop() }

        for await update in provider.anchorUpdates {
            switch update.event {
            case .added, .updated, .removed:
                processAnchors(from: provider)
            @unknown default:
                continue
            }
        }
    }

    /// Synchronous access to the latest frame (Leap-style GetFrame()).
    public func getFrame() -> HandFrame? {
        latestFrame
    }

    // MARK: - Internal

    private func processAnchors(from provider: HandTrackingProvider) {
        let anchors = provider.latestAnchors
        let timestamp = Date().timeIntervalSince1970

        // Build the new frame and cache it synchronously
        let frame = HandFrame(
            id: latestFrameID, // id will be incremented at publish time
            timestamp: timestamp,
            leftHand: anchors.leftHand.map { TrackedHand(anchor: $0) },
            rightHand: anchors.rightHand.map { TrackedHand(anchor: $0) }
        )
        latestFrame = frame

        // Coalesce multiple provider updates within the same run loop to a single SwiftUI change
        if !publishScheduled {
            publishScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Increment ID once per coalesced publish
                self.latestFrameID &+= 1
                // Invoke callback with the most recent frame
                if let latest = self.latestFrame {
                    self.onFrame?(latest)
                }
                self.publishScheduled = false
            }
        }
    }
}
