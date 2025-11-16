//
//  HandLabApp.swift
//  HandLab
//
//  Created by Antony Nasce on 15/11/2025.
//

import SwiftUI

import SwiftUI

@main
struct HandLabApp: App {
    @StateObject private var debugModel = HandDebugModel()

    var body: some Scene {
        // Normal window with controls
        WindowGroup {
            ControlPanelView()
                .environmentObject(debugModel)
        }

        // Immersive space with the 3D debug hands
        ImmersiveSpace(id: "HandLabSpace") {
            ImmersiveView()
                .environmentObject(debugModel)
        }
    }
}
