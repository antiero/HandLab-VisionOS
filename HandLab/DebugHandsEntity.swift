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

    private let leftDebugHand = DebugHandEntity(label: "L")
    private let rightDebugHand = DebugHandEntity(label: "R")

    // Entity’s designated init is `required`, so we must also mark this required.
    required init() {
        super.init()

        // Arrange the two debug hands next to each other in local space.
        leftDebugHand.position = SIMD3<Float>(-0.08, 0, 0)
        rightDebugHand.position = SIMD3<Float>(0.08, 0, 0)

        addChild(leftDebugHand)
        addChild(rightDebugHand)
    }

    /// Update the debug visual from the latest frame.
    func update(with frame: HandFrame) {
        if let left = frame.leftHand {
            leftDebugHand.isEnabled = true
            leftDebugHand.update(with: left)
        } else {
            leftDebugHand.isEnabled = false
        }

        if let right = frame.rightHand {
            rightDebugHand.isEnabled = true
            rightDebugHand.update(with: right)
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

    /// Required by `Entity` when subclassing.
    required init() {
        self.label = ""
        super.init()
        setupGeometry()
    }

    /// Pre-create all joints and bones so we just move them every frame.
    private func setupGeometry() {
        let jointMesh = MeshResource.generateSphere(radius: jointRadius)
        let jointMaterial = SimpleMaterial() // default material (no UIKit / Color fuss)

        for name in jointNames {
            let sphere = ModelEntity(mesh: jointMesh, materials: [jointMaterial])
            sphere.name = "Joint_\(name)" // use description, not rawValue
            sphere.position = .zero
            jointSpheres[name] = sphere
            addChild(sphere)
        }

        // Note: height comes before radius in this overload.
        let boneMesh = MeshResource.generateCylinder(height: 1.0, radius: boneRadius)
        let boneMaterial = SimpleMaterial()

        for (from, to) in bonePairs {
            let key = boneKey(from: from, to: to)
            let bone = ModelEntity(mesh: boneMesh, materials: [boneMaterial])
            bone.name = "Bone_\(from)_\(to)"
            bone.transform = Transform() // identity transform
            boneEntities[key] = bone
            addChild(bone)
        }
    }

    /// Update this debug hand with new tracking data.
    func update(with hand: TrackedHand) {
        // Use wrist as the origin for the miniature model.
        guard let wristWorld = hand.wristPosition else {
            for sphere in jointSpheres.values { sphere.isEnabled = false }
            for bone in boneEntities.values { bone.isEnabled = false }
            return
        }

        // Cache joint positions relative to wrist (then scaled).
        var localJointPositions: [HandSkeleton.JointName: SIMD3<Float>] = [:]

        for (name, sphere) in jointSpheres {
            if let worldPos = hand.jointPosition(name) {
                var local = worldPos - wristWorld
                local *= debugScale
                sphere.position = local
                sphere.isEnabled = true
                localJointPositions[name] = local
            } else {
                sphere.isEnabled = false
            }
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

