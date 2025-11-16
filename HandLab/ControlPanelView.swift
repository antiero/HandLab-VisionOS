//
//  ControlPanelView.swift
//  HandLab
//
//  Created by Antony Nasce on 16/11/2025.
//

import SwiftUI

struct ControlPanelView: View {
    @EnvironmentObject var debugModel: HandDebugModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var immersiveIsOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HandLab Control Panel")
                .font(.title)
                .bold()

            Text("Hand Visualisation")
                .font(.headline)

            Toggle("Follow translation (tiny hands move)",
                   isOn: $debugModel.followTranslation)
                .toggleStyle(.switch)

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
        .frame(idealWidth: 420, idealHeight: 320)
    }
}
