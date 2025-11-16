//
//  ImmersiveView.swift
//  HandLab
//
//  Created by Antony Nasce on 15/11/2025.
//

import SwiftUI
import RealityKit
import ARKit
import Combine
import VisionHandKit

struct ImmersiveView: View {
    @EnvironmentObject var debugModel: HandDebugModel

    // We own a single debug entity instance and add it to the scene once.
    @State private var debugHandsEntity = DebugHandsEntity()

    var body: some View {
        RealityView { content in
            // Main test entity (optional)
            let sphere = ModelEntity(mesh: .generateSphere(radius: 0.01))
            sphere.position = [0, 1, -0.5]
            content.add(sphere)

            // Add our persistent debug entity
            debugHandsEntity.name = "HandDebugPanel"
            debugHandsEntity.position = SIMD3<Float>(0, 0.8, -0.8) // in front of user
            content.add(debugHandsEntity)

        } update: { _ in
            // We no longer rely on this for frame updates.
            // RealityKit will still tick physics/rendering as needed.
        }
        .task {
            // Start hand tracking whenever the immersive space is active.
            do {
                try await debugModel.hands.run()
            } catch {
                print("Hand tracking failed: \(error)")
            }
        }
        // React to followTranslation changes from the window control panel.
        .onReceive(debugModel.$followTranslation) { follow in
            debugHandsEntity.mode = follow ? .follow : .anchored
        }
        // Drive the tiny hand rig directly from the incoming frames.
        .onReceive(debugModel.hands.$latestFrame.compactMap { $0 }) { frame in
            debugHandsEntity.update(with: frame)
        }
    }
}


#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
