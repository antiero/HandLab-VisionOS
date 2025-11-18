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

    @State private var immersiveIsOpen = false

    var body: some View {
        @Bindable var debugModel = debugModel   // local bindable handle

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

            // Colors
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

            // Radii
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

            Text("Immersive Space")
                .font(.headline)

            HStack {
                if immersiveIsOpen {
                    Button("Close Immersive View") {
                        Task {
                            await dismissImmersiveSpace()
                            immersiveIsOpen = false
                        }
                    }
                } else {
                    Button("Open Immersive View") {
                        Task {
                            _ = await openImmersiveSpace(id: "HandLabSpace")
                            immersiveIsOpen = true
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 380)

        // 1) Start hand tracking as soon as the control panel appears
        .task {
            do { try await debugModel.hands.run() }
            catch { print("Hand tracking failed: \(error)") }
        }

        // 2) Auto-open the immersive space on first launch
        .task {
            guard !immersiveIsOpen else { return }
            _ = await openImmersiveSpace(id: "HandLabSpace")
            immersiveIsOpen = true
        }
    }
}



#Preview {
    ControlPanelView()
        .environment(HandDebugModel())
}
