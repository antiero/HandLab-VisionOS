//
//  ImmersiveView.swift
//  HandLab
//
//  Created by Antony Nasce on 15/11/2025.
//

import SwiftUI
import RealityKit
import ARKit
import VisionHandKit
import UIKit

struct ImmersiveView: View {
    @Environment(HandDebugModel.self) private var debugModel

    @State private var debugHandsEntity = DebugHandsEntity()

    var body: some View {
        RealityView { content in
            let sphere = ModelEntity(mesh: .generateSphere(radius: 0.001))
            sphere.position = [0, 1.0, -0.5]
            content.add(sphere)

            debugHandsEntity.name = "HandDebugPanel"
            debugHandsEntity.position = SIMD3<Float>(0, 1.0, -0.5)
            content.add(debugHandsEntity)
        }
        // Observation-powered reactions
        .onChange(of: debugModel.followTranslation) { _, follow in
            debugHandsEntity.mode = follow ? .follow : .anchored
        }
        .onChange(of: debugModel.absolutePositions) { _, absolute in
            debugHandsEntity.absolutePositions = absolute
        }
        .onChange(of: debugModel.leftHandColor) { _, color in
            debugHandsEntity.setLeftHandColor(UIColor(color))
        }
        .onChange(of: debugModel.rightHandColor) { _, color in
            debugHandsEntity.setRightHandColor(UIColor(color))
        }
        .onChange(of: debugModel.boneColor) { _, color in
            debugHandsEntity.setBoneColor(UIColor(color))
        }
        .onChange(of: debugModel.jointRadius) { _, radius in
            debugHandsEntity.setJointRadius(Float(radius))
        }
        .onChange(of: debugModel.boneRadius) { _, radius in
            debugHandsEntity.setBoneRadius(Float(radius))
        }
        // Drive the skeleton from latestFrameID
        .onChange(of: debugModel.hands.latestFrameID) { _, _ in
            if let frame = debugModel.hands.latestFrame {
                debugHandsEntity.update(with: frame)
            }
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(HandDebugModel())
}
