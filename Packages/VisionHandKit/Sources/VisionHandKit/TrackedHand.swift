import Foundation
import ARKit
import simd

/// Wrapper around ARKit's HandAnchor with Leap-style helpers.
public struct TrackedHand: Sendable {
    public let anchor: HandAnchor

    public init(anchor: HandAnchor) {
        self.anchor = anchor
    }

    // MARK: - Basic properties

    /// Left/right hand.
    public var chirality: HandAnchor.Chirality {
        anchor.chirality
    }

    /// Whether ARKit is currently tracking this hand.
    public var isTracked: Bool {
        anchor.isTracked
    }

    /// World transform of the hand's origin (roughly wrist/palm base).
    public var worldTransform: simd_float4x4 {
        anchor.originFromAnchorTransform
    }

    // MARK: - Joint access

    /// Low-level: access an ARKit joint.
    public func joint(_ name: HandSkeleton.JointName) -> HandSkeleton.Joint? {
        anchor.handSkeleton?.joint(name)
    }

    /// World-space transform for a specific joint.
    ///
    /// Uses: jointTransform = originFromAnchor * anchorFromJoint.
    public func jointTransform(_ name: HandSkeleton.JointName) -> simd_float4x4? {
        guard let joint = joint(name) else { return nil }
        return anchor.originFromAnchorTransform * joint.anchorFromJointTransform
    }

    /// World-space position for a joint.
    public func jointPosition(_ name: HandSkeleton.JointName) -> SIMD3<Float>? {
        guard let transform = jointTransform(name) else { return nil }
        let c = transform.columns.3
        return SIMD3<Float>(c.x, c.y, c.z)
    }

    // MARK: - “Palm” approximations

    /// Approximate palm center as the average of the 4 finger knuckles.
    public var palmPosition: SIMD3<Float>? {
        let knuckles: [HandSkeleton.JointName] = [
            .indexFingerKnuckle,
            .middleFingerKnuckle,
            .ringFingerKnuckle,
            .littleFingerKnuckle
        ]

        let positions = knuckles.compactMap { jointPosition($0) }
        guard !positions.isEmpty else { return nil }

        let sum = positions.reduce(SIMD3<Float>(repeating: 0)) { $0 + $1 }
        return sum / Float(positions.count)
    }

    /// Rough palm normal:
    /// use wrist→index and wrist→little to build a basis.
    public var palmNormal: SIMD3<Float>? {
        guard
            let wrist = jointPosition(.wrist),
            let index = jointPosition(.indexFingerKnuckle),
            let little = jointPosition(.littleFingerKnuckle)
        else { return nil }

        let xAxis = simd_normalize(index - wrist)
        let zAxis = simd_normalize(little - wrist)
        let normal = simd_normalize(simd_cross(zAxis, xAxis))
        return normal
    }

    // MARK: - Common fingertip helpers

    public var wristPosition: SIMD3<Float>? {
        jointPosition(.wrist)
    }

    public var thumbTipPosition: SIMD3<Float>? {
        jointPosition(.thumbTip)
    }

    public var indexTipPosition: SIMD3<Float>? {
        jointPosition(.indexFingerTip)
    }

    public var middleTipPosition: SIMD3<Float>? {
        jointPosition(.middleFingerTip)
    }

    public var ringTipPosition: SIMD3<Float>? {
        jointPosition(.ringFingerTip)
    }

    public var littleTipPosition: SIMD3<Float>? {
        jointPosition(.littleFingerTip)
    }

    // MARK: - Pinch helpers

    /// Distance between thumb and index fingertips in metres.
    public func pinchDistance() -> Float? {
        guard let thumb = thumbTipPosition,
              let index = indexTipPosition
        else { return nil }
        return simd_distance(thumb, index)
    }

    /// A crude, normalized pinch strength 0–1, based on thumb–index distance.
    ///
    /// - Parameters:
    ///   - openDistance: distance treated as “fully open”
    ///   - closedDistance: distance treated as “fully pinched”
    public func pinchStrength(
        openDistance: Float = 0.05,
        closedDistance: Float = 0.01
    ) -> Float? {
        guard let d = pinchDistance() else { return nil }
        let t = (d - closedDistance) / (openDistance - closedDistance)
        let clamped = max(0, min(1, t))
        return 1 - clamped
    }

    // MARK: - Simple “grab” heuristic

    /// Cheap "grab" estimate: how curled the non-thumb fingers are.
    /// 0 = open, 1 = closed-ish.
    public func grabStrength() -> Float? {
        guard let palm = palmPosition else { return nil }

        let tips = [
            indexTipPosition,
            middleTipPosition,
            ringTipPosition,
            littleTipPosition
        ].compactMap { $0 }

        guard !tips.isEmpty else { return nil }

        let distances = tips.map { simd_distance($0, palm) }
        let avg = distances.reduce(0, +) / Float(distances.count)

        // Tune these to taste.
        let openR: Float = 0.09
        let closedR: Float = 0.03
        let t = (avg - closedR) / (openR - closedR)
        let clamped = max(0, min(1, t))
        return 1 - clamped
    }
}
