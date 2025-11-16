//
//  DebugHandsEntity.swift
//  HandLab
//
//  Created by Antony Nasce on 15/11/2025.
//

import Foundation
import RealityKit
import ARKit
import simd
import VisionHandKit

/// Root entity that holds visualizers for left + right hands, side by side.
final class DebugHandsEntity: Entity {

    enum Mode {
        case anchored     // hands stay centred in their own panel
        case follow       // hands move in a volume
    }

    /// Whether left/right hands should preserve their real-world proximity
    /// instead of being artificially separated.
    var absolutePositions: Bool = false {
        didSet { updateChildOffsets() }
    }

    var mode: Mode = .anchored {
        didSet {
            if mode == .anchored {
                followOrigin = nil
            }
        }
    }

    private let leftDebugHand = DebugHandEntity(label: "L")
    private let rightDebugHand = DebugHandEntity(label: "R")

    /// World-space origin used in follow mode.
    private var followOrigin: SIMD3<Float>?

    /// How far apart to place the two hands in non-absolute follow mode.
    private let handSpacing: Float = 0.08

    required init() {
        super.init()

        addChild(leftDebugHand)
        addChild(rightDebugHand)

        updateChildOffsets()
    }

    /// Update offsets when we toggle absolutePositions.
    private func updateChildOffsets() {
        if absolutePositions {
            // Both hands share the same local origin: relative positions preserved.
            leftDebugHand.position = .zero
            rightDebugHand.position = .zero
        } else {
            // Slight separation for readability.
            leftDebugHand.position = SIMD3<Float>(-handSpacing, 0, 0)
            rightDebugHand.position = SIMD3<Float>(handSpacing, 0, 0)
        }
    }

    /// Update the debug visual from the latest frame.
    func update(with frame: HandFrame) {
        // In follow mode, lazily pick a world-space origin once.
        if mode == .follow && followOrigin == nil {
            if let l = frame.leftHand?.wristPosition {
                followOrigin = l
            } else if let r = frame.rightHand?.wristPosition {
                followOrigin = r
            }
        }

        let originForThisFrame = followOrigin

        if let left = frame.leftHand {
            leftDebugHand.isEnabled = true
            leftDebugHand.update(with: left,
                                 mode: mode,
                                 followOrigin: originForThisFrame)
        } else {
            leftDebugHand.isEnabled = false
        }

        if let right = frame.rightHand {
            rightDebugHand.isEnabled = true
            rightDebugHand.update(with: right,
                                  mode: mode,
                                  followOrigin: originForThisFrame)
        } else {
            rightDebugHand.isEnabled = false
        }
    }
}

/// Visualizer for a single hand: joints as spheres, bones as cylinders.
final class DebugHandEntity: Entity {

    /// Spheres for each joint.
    private var jointSpheres: [HandSkeleton.JointName: ModelEntity] = [:]

    /// Cylinders for each bone (keyed by "from-to" string).
    private var boneEntities: [String: ModelEntity] = [:]

    /// Global scale for the miniature hand.
    private let debugScale: Float = 0.2

    /// Radii for joints and bones.
    private let jointRadius: Float = 0.004
    private let boneRadius: Float = 0.002

    /// All joints we care about.
    private let jointNames: [HandSkeleton.JointName] = [
        .wrist,
        .forearmWrist,
        .forearmArm,

        .thumbKnuckle,
        .thumbIntermediateBase,
        .thumbIntermediateTip,
        .thumbTip,

        .indexFingerMetacarpal,
        .indexFingerKnuckle,
        .indexFingerIntermediateBase,
        .indexFingerIntermediateTip,
        .indexFingerTip,

        .middleFingerMetacarpal,
        .middleFingerKnuckle,
        .middleFingerIntermediateBase,
        .middleFingerIntermediateTip,
        .middleFingerTip,

        .ringFingerMetacarpal,
        .ringFingerKnuckle,
        .ringFingerIntermediateBase,
        .ringFingerIntermediateTip,
        .ringFingerTip,

        .littleFingerMetacarpal,
        .littleFingerKnuckle,
        .littleFingerIntermediateBase,
        .littleFingerIntermediateTip,
        .littleFingerTip
    ]

    /// Bone connections (pairs of joints).
    private lazy var bonePairs: [(HandSkeleton.JointName, HandSkeleton.JointName)] = [
        // Thumb chain
        (.wrist, .thumbKnuckle),
        (.thumbKnuckle, .thumbIntermediateBase),
        (.thumbIntermediateBase, .thumbIntermediateTip),
        (.thumbIntermediateTip, .thumbTip),

        // Index chain
        (.wrist, .indexFingerMetacarpal),
        (.indexFingerMetacarpal, .indexFingerKnuckle),
        (.indexFingerKnuckle, .indexFingerIntermediateBase),
        (.indexFingerIntermediateBase, .indexFingerIntermediateTip),
        (.indexFingerIntermediateTip, .indexFingerTip),

        // Middle chain
        (.wrist, .middleFingerMetacarpal),
        (.middleFingerMetacarpal, .middleFingerKnuckle),
        (.middleFingerKnuckle, .middleFingerIntermediateBase),
        (.middleFingerIntermediateBase, .middleFingerIntermediateTip),
        (.middleFingerIntermediateTip, .middleFingerTip),

        // Ring chain
        (.wrist, .ringFingerMetacarpal),
        (.ringFingerMetacarpal, .ringFingerKnuckle),
        (.ringFingerKnuckle, .ringFingerIntermediateBase),
        (.ringFingerIntermediateBase, .ringFingerIntermediateTip),
        (.ringFingerIntermediateTip, .ringFingerTip),

        // Little chain
        (.wrist, .littleFingerMetacarpal),
        (.littleFingerMetacarpal, .littleFingerKnuckle),
        (.littleFingerKnuckle, .littleFingerIntermediateBase),
        (.littleFingerIntermediateBase, .littleFingerIntermediateTip),
        (.littleFingerIntermediateTip, .littleFingerTip)
    ]

    private let label: String

    init(label: String) {
        self.label = label
        super.init()
        setupGeometry()
    }

    required init() {
        self.label = ""
        super.init()
        setupGeometry()
    }

    /// Pre-create all joints and bones so we just move them every frame.
    private func setupGeometry() {
        let jointMesh = MeshResource.generateSphere(radius: jointRadius)
        let jointMaterial = SimpleMaterial()

        for name in jointNames {
            let sphere = ModelEntity(mesh: jointMesh, materials: [jointMaterial])
            sphere.name = "Joint_\(name)"
            sphere.position = .zero
            jointSpheres[name] = sphere
            addChild(sphere)
        }

        let boneMesh = MeshResource.generateCylinder(height: 1.0, radius: boneRadius)
        let boneMaterial = SimpleMaterial()

        for (from, to) in bonePairs {
            let key = boneKey(from: from, to: to)
            let bone = ModelEntity(mesh: boneMesh, materials: [boneMaterial])
            bone.name = "Bone_\(from)_\(to)"
            bone.transform = Transform()
            boneEntities[key] = bone
            addChild(bone)
        }
    }

    /// Update this debug hand with new tracking data.
    func update(with hand: TrackedHand,
                mode: DebugHandsEntity.Mode,
                followOrigin: SIMD3<Float>?) {

        guard let wristWorld = hand.wristPosition else {
            for sphere in jointSpheres.values { sphere.isEnabled = false }
            for bone in boneEntities.values { bone.isEnabled = false }
            return
        }

        // Cache joint positions relative to some base world position,
        // which depends on the mode.
        var localJointPositions: [HandSkeleton.JointName: SIMD3<Float>] = [:]

        for (name, sphere) in jointSpheres {
            guard let worldPos = hand.jointPosition(name) else {
                sphere.isEnabled = false
                continue
            }

            let baseWorld: SIMD3<Float>
            switch mode {
            case .anchored:
                // Current behaviour: mini-hand centred on its own wrist.
                baseWorld = wristWorld
            case .follow:
                // Use a shared origin for both hands, so they translate.
                baseWorld = followOrigin ?? wristWorld
            }

            var local = worldPos - baseWorld
            local *= debugScale
            sphere.position = local
            sphere.isEnabled = true
            localJointPositions[name] = local
        }

        // Update bones using the local joint positions.
        for (from, to) in bonePairs {
            let key = boneKey(from: from, to: to)
            guard let bone = boneEntities[key],
                  let a = localJointPositions[from],
                  let b = localJointPositions[to] else {
                boneEntities[key]?.isEnabled = false
                continue
            }

            updateBoneEntity(bone, from: a, to: b)
        }
    }

    // MARK: - Helpers

    private func boneKey(from: HandSkeleton.JointName, to: HandSkeleton.JointName) -> String {
        "\(from)->\(to)"
    }

    /// Position + orient a cylinder (height 1 in local neutral space) between two points.
    private func updateBoneEntity(_ bone: ModelEntity, from a: SIMD3<Float>, to b: SIMD3<Float>) {
        let dir = b - a
        let length = simd_length(dir)
        if length < 1e-4 {
            bone.isEnabled = false
            return
        }

        bone.isEnabled = true

        let mid = (a + b) / 2.0
        let yAxis = SIMD3<Float>(0, 1, 0)
        let dirNorm = simd_normalize(dir)

        // Rotation from Y axis to direction.
        let dot = simd_dot(yAxis, dirNorm)
        let rotation: simd_quatf

        if abs(dot - 1) < 1e-5 {
            rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        } else if abs(dot + 1) < 1e-5 {
            rotation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        } else {
            let axis = simd_normalize(simd_cross(yAxis, dirNorm))
            let angle = acos(dot)
            rotation = simd_quatf(angle: angle, axis: axis)
        }

        bone.transform = Transform(
            scale: SIMD3<Float>(1, length, 1),
            rotation: rotation,
            translation: mid
        )
    }
}

