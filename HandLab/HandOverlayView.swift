//
//  HandOverlayView.swift
//  HandLab
//
//  Created by Assistant on 07/01/2026
//

import SwiftUI
import RealityKit
import VisionHandKit
import simd
import UIKit
import ARKit

struct HandOverlayView: View {
    @Environment(HandDebugModel.self) private var debugModel

    @State private var leftEntity = OverlayHandEntity(color: UIColor.systemBlue)
    @State private var rightEntity = OverlayHandEntity(color: UIColor.systemRed)

    var body: some View {
        Group {
            if debugModel.showHandOverlays {
                RealityView { content in
                    if content.entities.contains(where: { $0.name == "HandOverlayRoot" }) {
                        return
                    }

                    let root = Entity()
                    root.name = "HandOverlayRoot"
                    content.add(root)

                    leftEntity.name = "LeftOverlayHand"
                    rightEntity.name = "RightOverlayHand"

                    root.addChild(leftEntity)
                    root.addChild(rightEntity)

                    // Initial sync for colors and radius
                    leftEntity.updateJointColor(UIColor(debugModel.leftHandColor))
                    rightEntity.updateJointColor(UIColor(debugModel.rightHandColor))
                    leftEntity.updateJointRadius(Float(debugModel.jointRadius))
                    rightEntity.updateJointRadius(Float(debugModel.jointRadius))
                    
                    leftEntity.updateBoneColor(UIColor(debugModel.boneColor))
                    rightEntity.updateBoneColor(UIColor(debugModel.boneColor))
                    leftEntity.updateBoneRadius(Float(debugModel.boneRadius))
                    rightEntity.updateBoneRadius(Float(debugModel.boneRadius))
                    leftEntity.setShowBones(debugModel.showOverlayBones)
                    rightEntity.setShowBones(debugModel.showOverlayBones)

                    // Apply latest frame immediately so spheres appear without waiting for next update
                    if let frame = debugModel.hands.latestFrame {
                        if let left = frame.leftHand {
                            leftEntity.isEnabled = true
                            leftEntity.update(with: left)
                        } else {
                            leftEntity.isEnabled = false
                        }
                        if let right = frame.rightHand {
                            rightEntity.isEnabled = true
                            rightEntity.update(with: right)
                        } else {
                            rightEntity.isEnabled = false
                        }
                    } else {
                        leftEntity.isEnabled = false
                        rightEntity.isEnabled = false
                    }
                }
                .onChange(of: debugModel.leftHandColor) { _, newColor in
                    leftEntity.updateJointColor(UIColor(newColor))
                }
                .onChange(of: debugModel.rightHandColor) { _, newColor in
                    rightEntity.updateJointColor(UIColor(newColor))
                }
                .onChange(of: debugModel.jointRadius) { _, newRadius in
                    leftEntity.updateJointRadius(Float(newRadius))
                    rightEntity.updateJointRadius(Float(newRadius))
                }
                .onChange(of: debugModel.boneColor) { _, newColor in
                    leftEntity.updateBoneColor(UIColor(newColor))
                    rightEntity.updateBoneColor(UIColor(newColor))
                }
                .onChange(of: debugModel.boneRadius) { _, newRadius in
                    leftEntity.updateBoneRadius(Float(newRadius))
                    rightEntity.updateBoneRadius(Float(newRadius))
                }
                .onChange(of: debugModel.showOverlayBones) { _, newValue in
                    leftEntity.setShowBones(newValue)
                    rightEntity.setShowBones(newValue)
                }
                .onChange(of: debugModel.hands.latestFrameID) { _, _ in
                    if let frame = debugModel.hands.latestFrame {
                        if let left = frame.leftHand {
                            leftEntity.isEnabled = true
                            leftEntity.update(with: left)
                        } else {
                            leftEntity.isEnabled = false
                        }
                        if let right = frame.rightHand {
                            rightEntity.isEnabled = true
                            rightEntity.update(with: right)
                        } else {
                            rightEntity.isEnabled = false
                        }
                    } else {
                        leftEntity.isEnabled = false
                        rightEntity.isEnabled = false
                    }
                }
            } else {
                Color.clear
            }
        }
    }
}

/// Minimal overlay hand that shows joint spheres at world positions.
private final class OverlayHandEntity: Entity {
    private var jointSpheres: [HandSkeleton.JointName: ModelEntity] = [:]
    private var boneEntities: [String: ModelEntity] = [:]
    private let baseBoneRadius: Float = 0.002
    private var boneRadiusScale: Float = 1.0
    private var boneColor: UIColor = .white
    private var showBones: Bool = false

    private let baseJointRadius: Float = 0.004
    private var jointRadiusScale: Float = 1.0

    private var jointColor: UIColor

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

    init(color: UIColor) {
        self.jointColor = color
        super.init()
        setupGeometry()
    }

    required init() {
        self.jointColor = .systemBlue
        super.init()
        setupGeometry()
    }

    private func setupGeometry() {
        let material = SimpleMaterial(color: jointColor, roughness: 0.3, isMetallic: false)
        let jointMesh = MeshResource.generateSphere(radius: baseJointRadius)
        for name in jointNames {
            let sphere = ModelEntity(mesh: jointMesh, materials: [material])
            sphere.name = "OverlayJoint_\(name)"
            sphere.position = .zero
            jointSpheres[name] = sphere
            addChild(sphere)
        }
        
        let boneMaterial = SimpleMaterial(color: boneColor, roughness: 0.5, isMetallic: false)
        let boneMesh = MeshResource.generateCylinder(height: 1.0, radius: baseBoneRadius)
        for (from, to) in bonePairs {
            let key = boneKey(from: from, to: to)
            let bone = ModelEntity(mesh: boneMesh, materials: [boneMaterial])
            bone.name = "OverlayBone_\(from)_\(to)"
            bone.transform = Transform()
            bone.isEnabled = false
            boneEntities[key] = bone
            addChild(bone)
        }
    }

    func updateJointRadius(_ radius: Float) {
        let scale = max(radius / baseJointRadius, 0.01)
        jointRadiusScale = scale
        for sphere in jointSpheres.values {
            sphere.scale = SIMD3<Float>(repeating: scale)
        }
    }

    func updateJointColor(_ color: UIColor) {
        jointColor = color
        let material = SimpleMaterial(color: color, roughness: 0.3, isMetallic: false)
        for sphere in jointSpheres.values {
            sphere.model?.materials = [material]
        }
    }
    
    func updateBoneRadius(_ radius: Float) {
        let scale = max(radius / baseBoneRadius, 0.01)
        boneRadiusScale = scale
    }

    func updateBoneColor(_ color: UIColor) {
        boneColor = color
        let material = SimpleMaterial(color: color, roughness: 0.5, isMetallic: false)
        for bone in boneEntities.values {
            bone.model?.materials = [material]
        }
    }

    func setShowBones(_ show: Bool) {
        showBones = show
        if !show {
            for bone in boneEntities.values {
                bone.isEnabled = false
            }
        }
    }

    func update(with hand: TrackedHand) {
        var worldJointPositions: [HandSkeleton.JointName: SIMD3<Float>] = [:]
        for (name, sphere) in jointSpheres {
            if let worldPos = hand.jointPosition(name) {
                sphere.isEnabled = true
                sphere.position = worldPos
                worldJointPositions[name] = worldPos
            } else {
                sphere.isEnabled = false
            }
        }

        for (from, to) in bonePairs {
            let key = boneKey(from: from, to: to)
            guard let bone = boneEntities[key] else { continue }
            guard showBones,
                  let a = worldJointPositions[from],
                  let b = worldJointPositions[to] else {
                bone.isEnabled = false
                continue
            }
            updateBoneEntity(bone, from: a, to: b)
        }
    }
    
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
            scale: SIMD3<Float>(boneRadiusScale, length, boneRadiusScale),
            rotation: rotation,
            translation: mid
        )
    }
}

#Preview {
    HandOverlayView()
        .environment(HandDebugModel())
}

