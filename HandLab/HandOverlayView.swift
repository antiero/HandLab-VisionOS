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
import AVFoundation

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
                    
                    leftEntity.setOverlayLift(Float(debugModel.overlayStripLift))
                    rightEntity.setOverlayLift(Float(debugModel.overlayStripLift))
                    
                    leftEntity.enableAudioPlayback = debugModel.showHandOverlays
                    rightEntity.enableAudioPlayback = debugModel.showHandOverlays

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
                .onChange(of: debugModel.overlayStripLift) { _, newValue in
                    leftEntity.setOverlayLift(Float(newValue))
                    rightEntity.setOverlayLift(Float(newValue))
                }
                .onChange(of: debugModel.showHandOverlays) { _, newValue in
                    leftEntity.enableAudioPlayback = newValue
                    rightEntity.enableAudioPlayback = newValue
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

    // Local finger enumeration for overlays
    private enum Finger: CaseIterable { case index, middle, ring, little }

    // A strip segment consists of a visible fill and a slightly larger outline behind it
    private struct StripSegment { let fill: ModelEntity; let outline: ModelEntity }
    private var fingerStripEntities: [Finger: [StripSegment]] = [:]

    // Simple audio cache and gate
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    var enableAudioPlayback: Bool = true

    // Track pressed joints to debounce
    private var pressedJoints: Set<HandSkeleton.JointName> = []

    // Visual for tap highlight
    private let tapHighlightColor: UIColor = .white
    private var overlayLiftDistance: Float = 0.012 // default 12mm toward viewer; positive = toward viewer
    func setOverlayLift(_ meters: Float) { overlayLiftDistance = meters }
    
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
        setupOverlays()
    }

    required init() {
        self.jointColor = .systemBlue
        super.init()
        setupGeometry()
        setupOverlays()
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
    
    private func setupOverlays() {
        let fillColor = UIColor.clear // transparent fill
        let outlineColor = UIColor.white // solid white outline
        let fillMaterial = UnlitMaterial(color: fillColor)
        let outlineMaterial = UnlitMaterial(color: outlineColor)

        func makeEllipseOutline(width: Float, height: Float, lineWidth: Float, material: UnlitMaterial) -> ModelEntity {
            let frame = ModelEntity()
            let thickness: Float = 0.0008
            let segments = 24
            let rx = width * 0.5
            let rz = height * 0.5
            var prevPoint = SIMD3<Float>(rx, 0, 0)
            for i in 1...segments {
                let a0 = Float(i - 1) / Float(segments) * 2 * .pi
                let a1 = Float(i) / Float(segments) * 2 * .pi
                let p0 = SIMD3<Float>(rx * cos(a0), 0, rz * sin(a0))
                let p1 = SIMD3<Float>(rx * cos(a1), 0, rz * sin(a1))
                let segVec = p1 - p0
                let segLen = max(simd_length(segVec), 1e-5)
                let mid = (p0 + p1) * 0.5
                // Create a thin rounded box segment oriented along the tangent
                let corner: Float = min(width, height) * 0.2
                let mesh = MeshResource.generateBox(size: [segLen, thickness, lineWidth], cornerRadius: corner * 0.2)
                let e = ModelEntity(mesh: mesh, materials: [material])
                // Rotate segment so its X axis aligns with segVec
                let xAxis = SIMD3<Float>(1, 0, 0)
                let t = segVec / segLen
                let dot = simd_dot(xAxis, t)
                let rot: simd_quatf
                if abs(dot - 1) < 1e-5 {
                    rot = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
                } else if abs(dot + 1) < 1e-5 {
                    rot = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
                } else {
                    let axis = simd_normalize(simd_cross(xAxis, t))
                    let angle = acos(dot)
                    rot = simd_quatf(angle: angle, axis: axis)
                }
                e.transform = Transform(scale: .one, rotation: rot, translation: mid)
                frame.addChild(e)
                prevPoint = p1
            }
            frame.isEnabled = false
            return frame
        }

        func makeStrip(width: Float, height: Float, material: UnlitMaterial) -> ModelEntity {
            let mesh = MeshResource.generatePlane(width: width, depth: height)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.isEnabled = false
            return entity
        }

        func makeSegments(for finger: Finger) -> [StripSegment] {
            let baseW: Float
            switch finger {
            case .index: baseW = 0.0185
            case .middle: baseW = 0.0190
            case .ring: baseW = 0.0175
            case .little: baseW = 0.0165
            }
            let baseH: Float = 0.04
            let outlineScale: Float = 1.25
            let lineWidth: Float = 0.004 // 4mm outline
            var segments: [StripSegment] = []
            for _ in 0..<3 {
                let fill = makeStrip(width: baseW, height: baseH, material: fillMaterial) // transparent fill
                let outline = makeEllipseOutline(width: baseW * outlineScale, height: baseH * outlineScale, lineWidth: lineWidth, material: outlineMaterial)
                segments.append(StripSegment(fill: fill, outline: outline))
            }
            return segments
        }

        fingerStripEntities[.index] = makeSegments(for: .index)
        fingerStripEntities[.middle] = makeSegments(for: .middle)
        fingerStripEntities[.ring] = makeSegments(for: .ring)
        fingerStripEntities[.little] = makeSegments(for: .little)

        for segments in fingerStripEntities.values {
            for seg in segments {
                addChild(seg.outline)
                addChild(seg.fill)
            }
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

        // Compute an approximate palm normal from wrist, index knuckle, and little knuckle (world space)
        let padNormalOpt: SIMD3<Float>? = {
            guard let wrist = worldJointPositions[.wrist],
                  let iKnuckle = worldJointPositions[.indexFingerKnuckle],
                  let lKnuckle = worldJointPositions[.littleFingerKnuckle] else { return nil }
            let v1 = iKnuckle - wrist
            let v2 = lKnuckle - wrist
            var n = simd_normalize(simd_cross(v1, v2))
            // Prefer normal facing roughly toward -Z (viewer heuristic)
            if simd_dot(n, SIMD3<Float>(0, 0, -1)) < 0 { n = -n }
            return n
        }()
        let palmFacingUser: Bool = {
            guard let n = padNormalOpt else { return false }
            return simd_dot(n, SIMD3<Float>(0, 0, -1)) > 0.2
        }()

        func fingerPoints(for finger: Finger) -> [HandSkeleton.JointName] {
            switch finger {
            case .index:
                return [.indexFingerKnuckle, .indexFingerIntermediateBase, .indexFingerIntermediateTip, .indexFingerTip]
            case .middle:
                return [.middleFingerKnuckle, .middleFingerIntermediateBase, .middleFingerIntermediateTip, .middleFingerTip]
            case .ring:
                return [.ringFingerKnuckle, .ringFingerIntermediateBase, .ringFingerIntermediateTip, .ringFingerTip]
            case .little:
                return [.littleFingerKnuckle, .littleFingerIntermediateBase, .littleFingerIntermediateTip, .littleFingerTip]
            }
        }

        func jointForSegment(finger: Finger, index: Int) -> HandSkeleton.JointName? {
            switch finger {
            case .index:
                switch index { case 0: return .indexFingerKnuckle; case 1: return .indexFingerIntermediateBase; case 2: return .indexFingerIntermediateTip; default: return nil }
            case .middle:
                switch index { case 0: return .middleFingerKnuckle; case 1: return .middleFingerIntermediateBase; case 2: return .middleFingerIntermediateTip; default: return nil }
            case .ring:
                switch index { case 0: return .ringFingerKnuckle; case 1: return .ringFingerIntermediateBase; case 2: return .ringFingerIntermediateTip; default: return nil }
            case .little:
                switch index { case 0: return .littleFingerKnuckle; case 1: return .littleFingerIntermediateBase; case 2: return .littleFingerIntermediateTip; default: return nil }
            }
        }

        let baseDepth: Float = 0.04 // baseline strip segment depth used for scaling
        for (finger, segments) in fingerStripEntities {
            guard let n = padNormalOpt, palmFacingUser else {
                for seg in segments { seg.fill.isEnabled = false; seg.outline.isEnabled = false }
                continue
            }

            // Gather the four points along the finger in world space
            let names = fingerPoints(for: finger)
            var pts: [SIMD3<Float>] = []
            var valid = true
            for name in names {
                if let p = worldJointPositions[name] { pts.append(p) } else { valid = false; break }
            }
            guard valid, pts.count == 4 else {
                for seg in segments { seg.fill.isEnabled = false; seg.outline.isEnabled = false }
                continue
            }

            // Build three segments following the finger curl: (p0->p1), (p1->p2), (p2->p3)
            for i in 0..<min(3, segments.count) {
                let a = pts[i]
                let b = pts[i + 1]
                let seg = segments[i]
                let v = b - a
                let len = simd_length(v)
                if len < 1e-5 {
                    seg.fill.isEnabled = false
                    seg.outline.isEnabled = false
                    continue
                }
                let t = v / len // tangent along finger
                var x = simd_cross(n, t)
                let xLen = simd_length(x)
                if xLen < 1e-5 {
                    seg.fill.isEnabled = false
                    seg.outline.isEnabled = false
                    continue
                }
                x /= xLen

                // Construct rotation from local plane axes: X->x, Y->n (plane normal), Z->t
                let rotMat = float3x3(columns: (
                    SIMD3<Float>(x.x, x.y, x.z),
                    SIMD3<Float>(n.x, n.y, n.z),
                    SIMD3<Float>(t.x, t.y, t.z)
                ))
                let rotation = simd_quatf(rotMat)
                let mid = (a + b) * 0.5
                let scale = SIMD3<Float>(1, 1, len / baseDepth)

                // Raise overlays further toward the viewer to avoid being occluded by passthrough hands
                let lift: SIMD3<Float> = n * overlayLiftDistance
                // Offset fill and outline slightly along the pad normal for a clean edge
                let fillTransform = Transform(scale: scale, rotation: rotation, translation: mid + lift + n * 0.001)
                let outlineTransform = Transform(scale: scale, rotation: rotation, translation: mid + lift - n * 0.001)
                seg.fill.transform = fillTransform
                seg.outline.transform = outlineTransform
                seg.fill.isEnabled = true
                seg.outline.isEnabled = true

                // Thumb contact against this segment (capsule test around segment)
                if let thumbTip = worldJointPositions[.thumbTip] {
                    let ap = thumbTip - a
                    let proj = simd_dot(ap, t)
                    let clamped = simd_clamp(proj, 0, len)
                    let closest = a + t * clamped
                    let lateral = simd_length(thumbTip - closest)
                    let halfWidth: Float = 0.009 // half of ~18mm
                    if let mappedJoint = jointForSegment(finger: finger, index: i) {
                        let wasPressed = pressedJoints.contains(mappedJoint)
                        let isNowPressed = lateral < halfWidth
                        if isNowPressed && !wasPressed {
                            pressedJoints.insert(mappedJoint)
                            if enableAudioPlayback { playNote(for: mappedJoint) }
                            spawnTapEffect(at: closest)
                            spawnConfettiEffect(at: closest, normal: n)
                        } else if !isNowPressed && wasPressed {
                            pressedJoints.remove(mappedJoint)
                        }
                    }
                }
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

    private func spawnTapEffect(at position: SIMD3<Float>) {
        let radius: Float = max(baseJointRadius * 0.9, 0.001)
        let mesh = MeshResource.generateSphere(radius: radius)
        let material = SimpleMaterial(color: tapHighlightColor, roughness: 0.1, isMetallic: false)
        let pulse = ModelEntity(mesh: mesh, materials: [material])
        pulse.position = position
        addChild(pulse)

        let startScale: SIMD3<Float> = SIMD3<Float>(repeating: 0.6)
        let endScale: SIMD3<Float> = SIMD3<Float>(repeating: 2.2)
        pulse.scale = startScale

        let duration: TimeInterval = 0.25
        DispatchQueue.main.async {
            UIView.animate(withDuration: duration, animations: {
                pulse.scale = endScale
                if var model = pulse.model, !model.materials.isEmpty,
                   var simple = model.materials[0] as? SimpleMaterial {
                    var color = self.tapHighlightColor
                    color = color.withAlphaComponent(0.0)
                    simple.color = .init(tint: color)
                    model.materials = [simple]
                    pulse.model = model
                }
            }, completion: { _ in
                pulse.removeFromParent()
            })
        }
    }

    private func spawnConfettiEffect(at position: SIMD3<Float>, normal n: SIMD3<Float>) {
        let particleCount = 12
        let minDist: Float = 0.008
        let maxDist: Float = 0.02
        let dotRadius: Float = 0.0015
        let baseColor = UIColor.white
        let material = SimpleMaterial(color: baseColor, roughness: 0.0, isMetallic: false)
        for _ in 0..<particleCount {
            let dot = ModelEntity(mesh: MeshResource.generateSphere(radius: dotRadius), materials: [material])
            dot.position = position
            addChild(dot)
            // Random direction on hemisphere oriented by n
            var dir: SIMD3<Float>
            repeat {
                let rx = Float.random(in: -1...1)
                let ry = Float.random(in: 0...1) // bias outward
                let rz = Float.random(in: -1...1)
                dir = simd_normalize(SIMD3<Float>(rx, ry, rz))
            } while !(dir.x.isFinite && dir.y.isFinite && dir.z.isFinite) || simd_length(dir) < 0.1
            // Orient hemisphere roughly along n
            if simd_dot(dir, n) < 0 { dir = -dir }
            let dist = Float.random(in: minDist...maxDist)
            let target = position + dir * dist
            // Animate translation and fade out
            let duration: TimeInterval = 0.35
            DispatchQueue.main.async {
                UIView.animate(withDuration: duration, animations: {
                    dot.position = target
                    if var model = dot.model, !model.materials.isEmpty,
                       var simple = model.materials[0] as? SimpleMaterial {
                        var c = baseColor
                        c = c.withAlphaComponent(0.0)
                        simple.color = .init(tint: c)
                        model.materials = [simple]
                        dot.model = model
                    }
                    dot.scale = SIMD3<Float>(repeating: 0.4)
                }, completion: { _ in
                    dot.removeFromParent()
                })
            }
        }
    }

    private func playNote(for joint: HandSkeleton.JointName) {
        guard enableAudioPlayback else { return }
        let key = "note_\(joint)"
        if let player = audioPlayers[key], player.isPlaying == false {
            player.currentTime = 0
            player.play()
            return
        }
        let fileCandidates = [
            "kalimba1", "kalimba2", "kalimba3", "kalimba4", "kalimba5", "kalimba6", "kalimba7", "kalimba8"
        ]
        let idx = abs(joint.hashValue) % fileCandidates.count
        let name = fileCandidates[idx]
        let url =
            Bundle.main.url(forResource: name, withExtension: "wav") ??
            Bundle.main.url(forResource: name, withExtension: "mp3") ??
            Bundle.main.url(forResource: name, withExtension: "caf")
        if let url {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = 0.8
                player.prepareToPlay()
                audioPlayers[key] = player
                player.play()
            } catch {
                // Silent fail in prototype
            }
        } else if let dataAsset = NSDataAsset(name: name) {
            do {
                let player = try AVAudioPlayer(data: dataAsset.data)
                player.volume = 0.8
                player.prepareToPlay()
                audioPlayers[key] = player
                player.play()
            } catch {
                // Silent fail in prototype
            }
        }
    }
}

#Preview {
    HandOverlayView()
        .environment(HandDebugModel())
}

