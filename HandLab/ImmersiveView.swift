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

import SwiftUI
import RealityKit
import ARKit
import Combine
import VisionHandKit

struct ImmersiveView: View {
    @StateObject private var hands = VisionHandClient()

    var body: some View {
        RealityView { content in
            // Main scene content (if you want other entities)
            // e.g. a test sphere you can poke:
//            let sphere = ModelEntity(mesh: .generateSphere(radius: 0.05))
//            sphere.position = [0, 1.3, -0.5]
//            content.add(sphere)

            // Hand debug panel
            let debug = DebugHandsEntity()
            debug.name = "HandDebugPanel"
            debug.position = SIMD3<Float>(0, 1.2, -0.8)  // In front of the user
            content.add(debug)

        } update: { content in
            // Drive the debug panel from the latest VisionHandKit frame.
            guard
                let debug = content.entities.first(where: { $0.name == "HandDebugPanel" }) as? DebugHandsEntity,
                let frame = hands.latestFrame
            else { return }

            debug.update(with: frame)
        }
        .task {
            do {
                try await hands.run()
            } catch {
                print("Hand tracking failed: \(error)")
            }
        }
        .onReceive(hands.$latestFrame.compactMap { $0 }) { frame in
            // Optional: keep your pinch logging (or other analytics) here.
//            if let right = frame.rightHand,
//               let pinch = right.pinchStrength() {
//                print("Right pinch:", pinch)
//            }
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
