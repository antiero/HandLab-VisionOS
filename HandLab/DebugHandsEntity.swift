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
import UIKit

/// Root entity that holds visualizers for left + right hands.
final class DebugHandsEntity: Entity {

    enum Mode {
        case anchored     // hands stay centred in their own panel
        case follow       // hands move in a volume
    }

    /// Whether left/right hands should preserve their real-world proximity.
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

    private let leftDebugHand: DebugHandEntity
    private let rightDebugHand: DebugHandEntity

    /// World-space origin used in follow mode.
    private var followOrigin: SIMD3<Float>?

    /// How far apart to place the two hands in non-absolute follow mode.
    private let handSpacing: Float = 0.08

    // Default Ultraleap-esque colors
    private var leftJointColor: UIColor = .systemBlue
    private var rightJointColor: UIColor = .systemRed
    private var boneColor: UIColor = .white

    required init() {
        leftDebugHand = DebugHandEntity(label: "L",
                                        jointColor: leftJointColor,
                                        boneColor: boneColor)
        rightDebugHand = DebugHandEntity(label: "R",
                                         jointColor: rightJointColor,
                                         boneColor: boneColor)

        super.init()

        addChild(leftDebugHand)
        addChild(rightDebugHand)

        updateChildOffsets()
    }

    /// Update offsets when we toggle absolutePositions.
    private func updateChildOffsets() {
        if absolutePositions {
            leftDebugHand.position = .zero
            rightDebugHand.position = .zero
        } else {
            leftDebugHand.position = SIMD3<Float>(-handSpacing, 0, 0)
            rightDebugHand.position = SIMD3<Float>(handSpacing, 0, 0)
        }
    }

    /// Set left-hand joint color.
    func setLeftHandColor(_ color: UIColor) {
        leftJointColor = color
        leftDebugHand.updateJointColor(color)
    }

    /// Set right-hand joint color.
    func setRightHandColor(_ color: UIColor) {
        rightJointColor = color
        rightDebugHand.updateJointColor(color)
    }

    /// Set bone color for both hands.
    func setBoneColor(_ color: UIColor) {
        boneColor = color
        leftDebugHand.updateBoneColor(color)
        rightDebugHand.updateBoneColor(color)
    }

    /// Update the debug visual from the latest frame.
    func update(with frame: HandFrame) {
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

    private var jointSpheres: [HandSkeleton.JointName: ModelEntity] = [:]
    private var boneEntities: [String: ModelEntity] = [:]

    /// Global scale for the miniature hand.
    private let debugScale: Float = 0.2

    /// Radii for joints and bones.
    private let jointRadius: Float = 0.004
    private let boneRadius: Float = 0.002

    /// Current colors.
    private var jointColor: UIColor
    private var boneColor: UIColor

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
        (.wrist, .thumbKnuckle),
        (.thumbKnuckle, .thumbIntermediateBase),
        (.thumbIntermediateBase, .thumbIntermediateTip),
        (.thumbIntermediateTip, .thumbTip),

        (.wrist, .indexFingerMetacarpal),
        (.indexFingerMetacarpal, .indexFingerKnuckle),
        (.indexFingerKnuckle, .indexFingerIntermediateBase),
        (.indexFingerIntermediateBase, .indexFingerIntermediateTip),
        (.indexFingerIntermediateTip, .indexFingerTip),

        (.wrist, .middleFingerMetacarpal),
        (.middleFingerMetacarpal, .middleFingerKnuckle),
        (.middleFingerKnuckle, .middleFingerIntermediateBase),
        (.middleFingerIntermediateBase, .middleFingerIntermediateTip),
        (.middleFingerIntermediateTip, .middleFingerTip),

        (.wrist, .ringFingerMetacarpal),
        (.ringFingerMetacarpal, .ringFingerKnuckle),
        (.ringFingerKnuckle, .ringFingerIntermediateBase),
        (.ringFingerIntermediateBase, .ringFingerIntermediateTip),
        (.ringFingerIntermediateTip, .ringFingerTip),

        (.wrist, .littleFingerMetacarpal),
        (.littleFingerMetacarpal, .littleFingerKnuckle),
        (.littleFingerKnuckle, .littleFingerIntermediateBase),
        (.littleFingerIntermediateBase, .littleFingerIntermediateTip),
        (.littleFingerIntermediateTip, .littleFingerTip)
    ]

    private let label: String

    init(label: String, jointColor: UIColor, boneColor: UIColor) {
        self.label = label
        self.jointColor = jointColor
        self.boneColor = boneColor
        super.init()
        setupGeometry()
    }

    required init() {
        self.label = ""
        self.jointColor = .systemBlue
        self.boneColor = .white
        super.init()
        setupGeometry()
    }

    /// Pre-create all joints and bones so we just move them every frame.
    private func setupGeometry() {
        let jointMaterial = SimpleMaterial(color: jointColor,
                                           roughness: 0.3,
                                           isMetallic: false)
        let jointMesh = MeshResource.generateSphere(radius: jointRadius)

        for name in jointNames {
            let sphere = ModelEntity(mesh: jointMesh, materials: [jointMaterial])
            sphere.name = "Joint_\(name)"
            sphere.position = .zero
            jointSpheres[name] = sphere
            addChild(sphere)
        }

        let boneMaterial = SimpleMaterial(color: boneColor,
                                          roughness: 0.5,
                                          isMetallic: false)
        let boneMesh = MeshResource.generateCylinder(height: 1.0, radius: boneRadius)

        for (from, to) in bonePairs {
            let key = boneKey(from: from, to: to)
            let bone = ModelEntity(mesh: boneMesh, materials: [boneMaterial])
            bone.name = "Bone_\(from)_\(to)"
            bone.transform = Transform()
            boneEntities[key] = bone
            addChild(bone)
        }
    }

    /// Change joint color at runtime.
    func updateJointColor(_ color: UIColor) {
        jointColor = color
        let material = SimpleMaterial(color: color,
                                      roughness: 0.3,
                                      isMetallic: false)
        for sphere in jointSpheres.values {
            sphere.model?.materials = [material]
        }
    }

    /// Change bone color at runtime.
    func updateBoneColor(_ color: UIColor) {
        boneColor = color
        let material = SimpleMaterial(color: color,
                                      roughness: 0.5,
                                      isMetallic: false)
        for bone in boneEntities.values {
            bone.model?.materials = [material]
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

        var localJointPositions: [HandSkeleton.JointName: SIMD3<Float>] = [:]

        for (name, sphere) in jointSpheres {
            guard let worldPos = hand.jointPosition(name) else {
                sphere.isEnabled = false
                continue
            }

            let baseWorld: SIMD3<Float>
            switch mode {
            case .anchored:
                baseWorld = wristWorld
            case .follow:
                baseWorld = followOrigin ?? wristWorld
            }

            var local = worldPos - baseWorld
            local *= debugScale
            sphere.position = local
            sphere.isEnabled = true
            localJointPositions[name] = local
        }

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

