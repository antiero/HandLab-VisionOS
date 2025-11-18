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
    @State private var debugModel = HandDebugModel()

    var body: some Scene {
        WindowGroup {
            ControlPanelView()
                .environment(debugModel)   // inject Observable model
        }

        ImmersiveSpace(id: "HandLabSpace") {
            ImmersiveView()
                .environment(debugModel)
        }
    }
}
