//
//  ControlPanelView.swift
//  HandLab
//
//  Created by Antony Nasce on 16/11/2025.
//

import SwiftUI
import VisionHandKit

struct ControlPanelView: View {
    @Environment(HandDebugModel.self) private var debugModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var immersiveIsOpen = false
    @State private var dioramaIsOpen = false

    var body: some View {
        @Bindable var debugModel = debugModel

        VStack(alignment: .leading, spacing: 16) {
            Text("HandLab Control Panel")
                .font(.title)
                .bold()

            Text("Hand Visualisation")
                .font(.headline)

            Toggle("Follow translation (tiny hands move)",
                   isOn: $debugModel.followTranslation)
                .toggleStyle(.switch)

            Toggle("Absolute world positions (preserve proximity)",
                   isOn: $debugModel.absolutePositions)
                .toggleStyle(.switch)
                .disabled(!debugModel.followTranslation)
                .opacity(debugModel.followTranslation ? 1.0 : 0.4)

            VStack(alignment: .leading, spacing: 8) {
                Text("Hand Colors")
                    .font(.headline)

                ColorPicker("Left hand joints",
                            selection: $debugModel.leftHandColor,
                            supportsOpacity: false)

                ColorPicker("Right hand joints",
                            selection: $debugModel.rightHandColor,
                            supportsOpacity: false)

                ColorPicker("Bone cylinders",
                            selection: $debugModel.boneColor,
                            supportsOpacity: false)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Geometry")
                    .font(.headline)

                VStack(alignment: .leading) {
                    Text("Joint radius: \(debugModel.jointRadius, specifier: "%.4f") m")
                        .font(.caption)
                    Slider(
                        value: $debugModel.jointRadius,
                        in: 0.001...0.005,
                        step: 0.0005
                    )
                }

                VStack(alignment: .leading) {
                    Text("Bone radius: \(debugModel.boneRadius, specifier: "%.4f") m")
                        .font(.caption)
                    Slider(
                        value: $debugModel.boneRadius,
                        in: 0.0005...0.005,
                        step: 0.0005
                    )
                }
            }

            Divider()
                .padding(.vertical, 8)

            Text("Tiny Hands Diorama")
                .font(.headline)

            HStack {
                Button(dioramaIsOpen ? "Close Diorama" : "Open Diorama") {
                    if dioramaIsOpen {
                        dismissWindow(id: "TinyHandsDiorama")
                        dioramaIsOpen = false
                    } else {
                        openWindow(id: "TinyHandsDiorama")
                        dioramaIsOpen = true
                    }
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(
            minWidth: 380, maxWidth: 420,
            minHeight: 700, maxHeight: 720
        )

        // 1) Ensure we’re in a Full Space so ARKit can stream hands.
        .task {
            guard !immersiveIsOpen else { return }

            let result = await openImmersiveSpace(id: "HandLabSpace")
            if case .opened = result {
                immersiveIsOpen = true
                print("[ControlPanel] Immersive space opened")
            } else {
                print("[ControlPanel] Failed to open immersive space: \(String(describing: result))")
            }
        }
    }
}

#Preview {
    ControlPanelView()
        .environment(HandDebugModel())
}
