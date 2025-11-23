//
//  TinyHandsVolumeView.swift
//  HandLab
//
//  Created by Antony Nasce on 15/11/2025.
//

import SwiftUI
import RealityKit
import VisionHandKit
import UIKit

/// Tiny-hands diorama content, hosted inside a volumetric window.
struct TinyHandsVolumeView: View {
    @Environment(HandDebugModel.self) private var debugModel

    @State private var debugHandsEntity = DebugHandsEntity()
    @State private var sceneInitialized = false

    var body: some View {
        baseRealityView
            .modifier(
                TinyHandsBindingsModifier(
                    debugModel: debugModel,
                    debugHandsEntity: debugHandsEntity
                )
            )
    }

    /// The core RealityView with the diorama scene.
    private var baseRealityView: some View {
        RealityView { content in
            guard !sceneInitialized else { return }
            sceneInitialized = true
            setupDiorama(in: content)
        }
    }

    /// Builds the small table + column and positions the tiny hands above it.
    private func setupDiorama(in content: RealityViewContent) {
        // Root of the diorama
        let dioramaRoot = Entity()
        dioramaRoot.name = "DioramaRoot"

        // --- Table top (simple low table / plinth) ---
        let tableRadius: Float = 0.20   // 20 cm
        let tableThickness: Float = 0.02

        let tableMesh = MeshResource.generateBox(
            size: [tableRadius * 2, tableThickness, tableRadius * 2],
            cornerRadius: 0.01
        )

        let tableColor = UIColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0)
        let tableMaterial = SimpleMaterial(color: tableColor, isMetallic: false)

        let tableEntity = ModelEntity(mesh: tableMesh, materials: [tableMaterial])
        tableEntity.name = "DioramaTableTop"
        tableEntity.position = SIMD3<Float>(0, -0.05, 0)

        // --- Short central column under the table (for aesthetics) ---
        let columnHeight: Float = 0.06
        let columnRadius: Float = 0.03

        let columnMesh = MeshResource.generateCylinder(
            height: columnHeight,
            radius: columnRadius
        )

        let columnMaterial = SimpleMaterial(
            color: UIColor(white: 0.10, alpha: 1.0),
            isMetallic: true
        )

        let columnEntity = ModelEntity(mesh: columnMesh, materials: [columnMaterial])
        columnEntity.name = "DioramaColumn"
        columnEntity.position = SIMD3<Float>(
            0,
            tableEntity.position.y - (tableThickness / 2) - (columnHeight / 2),
            0
        )

        // --- Tiny hands placement ---
        debugHandsEntity.name = "TinyHands"

        // Put the hands just above the table top
        debugHandsEntity.position = SIMD3<Float>(
            0,
            tableEntity.position.y + tableThickness / 2 + 0.03,
            0
        )

        dioramaRoot.addChild(tableEntity)
        dioramaRoot.addChild(columnEntity)
        dioramaRoot.addChild(debugHandsEntity)

        content.add(dioramaRoot)
    }
}

/// Handles all the bindings from HandDebugModel to DebugHandsEntity,
/// split out so the main view body stays simple.
private struct TinyHandsBindingsModifier: ViewModifier {
    let debugModel: HandDebugModel
    let debugHandsEntity: DebugHandsEntity

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Initial sync of settings to the hands entity
                applyAllSettings()
            }
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
            .onChange(of: debugModel.hands.latestFrameID) { _, _ in
                if let frame = debugModel.hands.latestFrame {
                    debugHandsEntity.update(with: frame)
                }
            }
    }

    private func applyAllSettings() {
        debugHandsEntity.mode = debugModel.followTranslation ? .follow : .anchored
        debugHandsEntity.absolutePositions = debugModel.absolutePositions
        debugHandsEntity.setLeftHandColor(UIColor(debugModel.leftHandColor))
        debugHandsEntity.setRightHandColor(UIColor(debugModel.rightHandColor))
        debugHandsEntity.setBoneColor(UIColor(debugModel.boneColor))
        debugHandsEntity.setJointRadius(Float(debugModel.jointRadius))
        debugHandsEntity.setBoneRadius(Float(debugModel.boneRadius))
    }
}

#Preview(immersionStyle: .mixed) {
    TinyHandsVolumeView()
        .environment(HandDebugModel())
}
