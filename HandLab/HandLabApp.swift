//
//  HandLabApp.swift
//  HandLab
//
//  Created by Antony Nasce on 15/11/2025.
//

import SwiftUI
import Observation

@main
struct HandLabApp: App {
    @State private var debugModel: HandDebugModel

    init() {
        let model = HandDebugModel()
        // Initialise @State with our instance
        _debugModel = State(initialValue: model)
        // Kick off hand tracking exactly once at app launch
        model.startHandTracking()
    }

    var body: some Scene {
        WindowGroup(id: "ControlPanel") {
            ControlPanelView()
                .environment(debugModel)
        }

        // Diorama volume hosting the tiny hands
        WindowGroup(id: "TinyHandsDiorama") {
            TinyHandsVolumeView()
                .environment(debugModel)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.3,
                     height: 0.3,
                     depth: 0.3,
                     in: .meters)
        
        // Minimal ImmersiveSpace, just to unlock ARKit hand tracking
        ImmersiveSpace(id: "HandLabSpace") {
            Color.clear               // no visible immersive content needed
        }
    }
}
