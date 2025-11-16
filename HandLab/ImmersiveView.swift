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
import UIKit

struct ImmersiveView: View {
    @EnvironmentObject var debugModel: HandDebugModel

    @State private var debugHandsEntity = DebugHandsEntity()

    var body: some View {
        RealityView { content in
            let sphere = ModelEntity(mesh: .generateSphere(radius: 0.001))
            sphere.position = [0, 1.0, -0.5]
            content.add(sphere)

            debugHandsEntity.name = "HandDebugPanel"
            debugHandsEntity.position = SIMD3<Float>(0, 1.0, -0.5)
            content.add(debugHandsEntity)

        } update: { _ in
            // no-op; we drive updates via Combine
        }
        .task {
            do {
                try await debugModel.hands.run()
            } catch {
                print("Hand tracking failed: \(error)")
            }
        }
        .onReceive(debugModel.$followTranslation) { follow in
            debugHandsEntity.mode = follow ? .follow : .anchored
        }
        .onReceive(debugModel.$absolutePositions) { absolute in
            debugHandsEntity.absolutePositions = absolute
        }
        .onReceive(debugModel.$leftHandColor) { color in
            debugHandsEntity.setLeftHandColor(UIColor(color))
        }
        .onReceive(debugModel.$rightHandColor) { color in
            debugHandsEntity.setRightHandColor(UIColor(color))
        }
        .onReceive(debugModel.$boneColor) { color in
            debugHandsEntity.setBoneColor(UIColor(color))
        }
        .onReceive(debugModel.hands.$latestFrame.compactMap { $0 }) { frame in
            debugHandsEntity.update(with: frame)
        }
    }
}




#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environmentObject(HandDebugModel())
}
