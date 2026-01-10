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
import AVFoundation

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
    
    /// Set joint radius (applies to both hands).
    func setJointRadius(_ radius: Float) {
        leftDebugHand.updateJointRadius(radius)
        rightDebugHand.updateJointRadius(radius)
    }

    /// Set bone radius (applies to both hands).
    func setBoneRadius(_ radius: Float) {
        leftDebugHand.updateBoneRadius(radius)
        rightDebugHand.updateBoneRadius(radius)
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
    
    /// Enable or disable audio playback for both hands (to avoid double triggers when overlays are active).
    func setAudioEnabled(_ enabled: Bool) {
        leftDebugHand.enableAudioPlayback = enabled
        rightDebugHand.enableAudioPlayback = enabled
    }

    /// Enable or disable tap visual feedback on both hands.
    func setTapFeedbackEnabled(_ enabled: Bool) {
        leftDebugHand.enableTapFeedback = enabled
        rightDebugHand.enableTapFeedback = enabled
    }

    /// Enable or disable chord strip overlays on both hands.
    func setChordStripsEnabled(_ enabled: Bool) {
        leftDebugHand.enableChordStrips = enabled
        rightDebugHand.enableChordStrips = enabled
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

    // Local finger enumeration since ARKit.HandSkeleton has no Finger type
    enum Finger: CaseIterable {
        case index, middle, ring, little
    }

    // A strip segment consists of a visible fill and a slightly larger outline behind it
    private struct StripSegment { let fill: ModelEntity; let outline: ModelEntity }
    private var fingerStripEntities: [Finger: [StripSegment]] = [:]

    // Simple audio: map a key id to AVAudioPlayer to avoid reloading
    private var audioPlayers: [String: AVAudioPlayer] = [:]

    // Track which joints are currently considered "pressed" to debounce taps
    private var pressedJoints: Set<HandSkeleton.JointName> = []
    // Gates to control where musical visuals should appear
    var enableTapFeedback: Bool = true
    var enableChordStrips: Bool = true

    var enableAudioPlayback: Bool = true

    // Simple visual to highlight a tap (animated sphere)
    private let tapHighlightColor: UIColor = .white

    /// Global scale for the miniature hand.
    private let debugScale: Float = 0.2

    /// Base radii for joints and bones (used for mesh generation).
    private let baseJointRadius: Float = 0.004
    private let baseBoneRadius: Float = 0.002

    /// Current scale factors relative to base radii.
    private var jointRadiusScale: Float = 1.0
    private var boneRadiusScale: Float = 1.0

    /// Current colors.
    private var jointColor: UIColor
    private var boneColor: UIColor

    /// All joints+bone pairs we care about.
    private let jointNames = HandTopology.allJoints
    private let bonePairs = HandTopology.boneEdges

    private let label: String

    init(label: String, jointColor: UIColor, boneColor: UIColor) {
        self.label = label
        self.jointColor = jointColor
        self.boneColor = boneColor
        super.init()
        setupGeometry()
        setupOverlaysAndEffects()
    }

    required init() {
        self.label = ""
        self.jointColor = .systemBlue
        self.boneColor = .white
        super.init()
        setupGeometry()
        setupOverlaysAndEffects()
    }

    /// Pre-create all joints and bones so we just move them every frame.
    private func setupGeometry() {
        let jointMaterial = UnlitMaterial(color: jointColor)

        let jointMesh = MeshResource.generateSphere(radius: baseJointRadius)

        for name in jointNames {
            let sphere = ModelEntity(mesh: jointMesh, materials: [jointMaterial])
            sphere.name = "Joint_\(name)"
            sphere.position = .zero
            jointSpheres[name] = sphere
            addChild(sphere)
        }

        let boneMaterial = UnlitMaterial(color: boneColor)

        let boneMesh = MeshResource.generateCylinder(height: 1.0, radius: baseBoneRadius)

        for (from, to) in bonePairs {
            let key = boneKey(from: from, to: to)
            let bone = ModelEntity(mesh: boneMesh, materials: [boneMaterial])
            bone.name = "Bone_\(from)_\(to)"
            bone.transform = Transform()
            boneEntities[key] = bone
            addChild(bone)
        }
    }
    
    /// Create finger strip overlays and a reusable particle emitter.
    private func setupOverlaysAndEffects() {
        // Less transparent fill with a strong outline for visibility
        let fillColor = UIColor.systemTeal.withAlphaComponent(0.85)
        let outlineColor = UIColor.black.withAlphaComponent(0.95)
        let fillMaterial = UnlitMaterial(color: fillColor)
        let outlineMaterial = UnlitMaterial(color: outlineColor)

        func makeStrip(width: Float, height: Float, material: UnlitMaterial) -> ModelEntity {
            // Use a thin rounded box so the strip has a soft outline shape rather than a flat plane
            let thickness: Float = 0.0008
            let corner: Float = min(width, height) * 0.35
            let mesh = MeshResource.generateBox(size: [width, thickness, height], cornerRadius: corner)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.isEnabled = false
            return entity
        }

        func makeSegments(for finger: Finger) -> [StripSegment] {
            // Slightly vary width per finger for a more anatomical look
            let baseW: Float
            switch finger {
            case .index: baseW = 0.0185
            case .middle: baseW = 0.0190
            case .ring: baseW = 0.0175
            case .little: baseW = 0.0165
            }
            let baseH: Float = 0.04
            let outlineScale: Float = 1.25
            var segments: [StripSegment] = []
            for _ in 0..<3 {
                let fill = makeStrip(width: baseW, height: baseH, material: fillMaterial)
                let outline = makeStrip(width: baseW * outlineScale, height: baseH * outlineScale, material: outlineMaterial)
                let seg = StripSegment(fill: fill, outline: outline)
                segments.append(seg)
            }
            return segments
        }

        fingerStripEntities[.index] = makeSegments(for: .index)
        fingerStripEntities[.middle] = makeSegments(for: .middle)
        fingerStripEntities[.ring] = makeSegments(for: .ring)
        fingerStripEntities[.little] = makeSegments(for: .little)

        for segments in fingerStripEntities.values {
            for seg in segments {
                addChild(seg.outline) // add outline first so it renders behind
                addChild(seg.fill)
            }
        }
        // ParticleEmitterComponent is not available here; tap highlighting is implemented
        // by spawning a small, animated sphere in `spawnTapEffect(at:)`.
    }
    
    /// Change joint radius at runtime (applies scale relative to base).
    func updateJointRadius(_ radius: Float) {
        let scale = max(radius / baseJointRadius, 0.01) // avoid zero / tiny
        jointRadiusScale = scale
        for sphere in jointSpheres.values {
            sphere.scale = SIMD3<Float>(repeating: scale)
        }
    }

    /// Change bone radius at runtime (applies scale relative to base).
    func updateBoneRadius(_ radius: Float) {
        let scale = max(radius / baseBoneRadius, 0.01)
        boneRadiusScale = scale
        // actual scale is applied in updateBoneEntity via boneRadiusScale
    }

    /// Change joint color at runtime.
    func updateJointColor(_ color: UIColor) {
        jointColor = color
        let material = UnlitMaterial(color: color)
        for sphere in jointSpheres.values {
            sphere.model?.materials = [material]
        }
    }

    /// Change bone color at runtime.
    func updateBoneColor(_ color: UIColor) {
        boneColor = color
        let material = UnlitMaterial(color: color)
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
            for segmentList in fingerStripEntities.values {
                for seg in segmentList {
                    seg.fill.isEnabled = false
                    seg.outline.isEnabled = false
                }
            }
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

        // Compute an approximate palm normal from wrist, index knuckle, and little knuckle.
        let padNormalOpt: SIMD3<Float>? = {
            guard let wrist = localJointPositions[.wrist],
                  let iKnuckle = localJointPositions[.indexFingerKnuckle],
                  let lKnuckle = localJointPositions[.littleFingerKnuckle] else { return nil }
            let v1 = iKnuckle - wrist
            let v2 = lKnuckle - wrist
            var n = simd_normalize(simd_cross(v1, v2))
            // Ensure normal points toward the viewer (-Z in our mini-hand space)
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
            guard enableChordStrips && palmFacingUser, let n = padNormalOpt else {
                for seg in segments { seg.fill.isEnabled = false; seg.outline.isEnabled = false }
                continue
            }

            // Gather the four points along the finger
            let names = fingerPoints(for: finger)
            var pts: [SIMD3<Float>] = []
            var valid = true
            for name in names {
                if let p = localJointPositions[name] { pts.append(p) } else { valid = false; break }
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
                let lift: SIMD3<Float> = n * 0.0015 // slightly above the pad
                // Offset fill and outline slightly along the pad normal for a clean edge
                let fillTransform = Transform(scale: scale, rotation: rotation, translation: mid + lift + n * 0.0003)
                let outlineTransform = Transform(scale: scale, rotation: rotation, translation: mid + lift - n * 0.0003)
                seg.fill.transform = fillTransform
                seg.outline.transform = outlineTransform
                seg.fill.isEnabled = true
                seg.outline.isEnabled = true

                // Thumb contact against this segment (capsule test around segment)
                if let thumbTip = localJointPositions[.thumbTip] {
                    let ap = thumbTip - a
                    let proj = simd_dot(ap, t)
                    let clamped = simd_clamp(proj, 0, len)
                    let closest = a + t * clamped
                    let lateral = simd_length(thumbTip - closest)
                    let halfWidth: Float = 0.009 // half of 0.018 width
                    if let mappedJoint = jointForSegment(finger: finger, index: i) {
                        let wasPressed = pressedJoints.contains(mappedJoint)
                        let isNowPressed = lateral < halfWidth
                        if isNowPressed && !wasPressed {
                            pressedJoints.insert(mappedJoint)
                            print("[DebugHandsEntity] Thumb contact with \(finger) segment #\(i) -> joint \(mappedJoint) [TRIGGER]")
                            if enableTapFeedback { spawnTapEffect(at: closest) }
                            playNote(for: mappedJoint)
                        } else if !isNowPressed && wasPressed {
                            pressedJoints.remove(mappedJoint)
                        }
                    } else if lateral < halfWidth {
                        // Fallback: still log contact
                        print("[DebugHandsEntity] Thumb contact with \(finger) segment #\(i) at lateral=\(lateral))")
                    }
                }
            }
        }

        // Detect thumb tip taps on finger joints
        if let thumbTip = localJointPositions[.thumbTip] {
            // Joints to test as keys
            let keyJoints: [HandSkeleton.JointName] = [
                .indexFingerKnuckle, .indexFingerIntermediateBase, .indexFingerIntermediateTip,
                .middleFingerKnuckle, .middleFingerIntermediateBase, .middleFingerIntermediateTip,
                .ringFingerKnuckle, .ringFingerIntermediateBase, .ringFingerIntermediateTip,
                .littleFingerKnuckle, .littleFingerIntermediateBase, .littleFingerIntermediateTip
            ]
            let activationDistance: Float = 0.01 // 1 cm in mini-hand space after debugScale

            for j in keyJoints {
                if let p = localJointPositions[j] {
                    let d = simd_length(p - thumbTip)
                    let isNowPressed = d < activationDistance
                    let wasPressed = pressedJoints.contains(j)
                    if isNowPressed && !wasPressed {
                        // Trigger
                        pressedJoints.insert(j)
                        if enableTapFeedback { spawnTapEffect(at: p) }
                        playNote(for: j)
                    } else if !isNowPressed && wasPressed {
                        pressedJoints.remove(j)
                    }
                }
            }
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
            scale: SIMD3<Float>(boneRadiusScale, length, boneRadiusScale),
            rotation: rotation,
            translation: mid
        )
    }

    private func spawnTapEffect(at position: SIMD3<Float>) {
        // Create a small sphere that scales up and fades out quickly to simulate a burst
        let radius: Float = max(baseJointRadius * 0.9, 0.001)
        let mesh = MeshResource.generateSphere(radius: radius)
        let material = UnlitMaterial(color: tapHighlightColor)
        let pulse = ModelEntity(mesh: mesh, materials: [material])
        pulse.position = position
        addChild(pulse)

        // Animate scale and opacity via a timed sequence
        let startScale: SIMD3<Float> = SIMD3<Float>(repeating: 0.6)
        let endScale: SIMD3<Float> = SIMD3<Float>(repeating: 2.2)
        pulse.scale = startScale

        let duration: TimeInterval = 0.25
        // Use a simple UIView animation on main queue to interpolate scale; RealityKit Animations
        // could also be used, but this avoids additional setup.
        DispatchQueue.main.async {
            UIView.animate(withDuration: duration, animations: {
                pulse.scale = endScale
                if var model = pulse.model, !model.materials.isEmpty {
                    // Reduce alpha by updating material color; UnlitMaterial is value-typed
                    if var unlit = model.materials[0] as? UnlitMaterial {
                        let c = self.tapHighlightColor.withAlphaComponent(0.0)
                        unlit.color = .init(tint: c)
                        model.materials = [unlit]
                        pulse.model = model
                    }
                }
            }, completion: { _ in
                pulse.removeFromParent()
            })
        }
    }

    private func playNote(for joint: HandSkeleton.JointName) {
        guard enableAudioPlayback else {
            print("[DebugHandsEntity] Audio disabled, skipping note for joint: \(joint)")
            return
        }
        // Map joint to a small set of pleasant notes.
        // We'll use system sounds packaged in the app later; for prototype, generate simple tones via bundled files if present.
        let key = "note_\(joint)"
        if let player = audioPlayers[key], player.isPlaying == false {
            player.currentTime = 0
            print("[DebugHandsEntity] Replaying cached note for joint: \(joint)")
            player.play()
            return
        }

        // Fallback: try to load short WAV/MP3/CAF files named by index (developer to include in bundle later)
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
            print("[DebugHandsEntity] Loading audio for joint: \(joint) from: \(url.lastPathComponent)")
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = 0.8
                player.prepareToPlay()
                audioPlayers[key] = player
                player.play()
                print("[DebugHandsEntity] Started audio for joint: \(joint)")
            } catch {
                print("[DebugHandsEntity] Failed to load audio for joint: \(joint), error: \(error)")
            }
        } else {
            print("[DebugHandsEntity] Audio file not found for base name: \(name) (tried wav/mp3/caf)")
        }
    }
}

