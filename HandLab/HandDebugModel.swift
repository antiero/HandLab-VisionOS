//
//  HandDebugModel.swift
//  HandLab
//
//  Created by Antony Nasce on 16/11/2025.
//

import SwiftUI
import Observation
import VisionHandKit

@MainActor
@Observable
final class HandDebugModel {
    var showHandOverlays: Bool = false
    var showOverlayBones: Bool = false

    var followTranslation: Bool = false
    var absolutePositions: Bool = false

    var leftHandColor: Color = .blue
    var rightHandColor: Color = .red
    var boneColor: Color = .white

    var jointRadius: Double = 0.004
    var boneRadius: Double = 0.002
    var overlayStripLift: Double = 0.012 // meters; positive moves overlays toward the viewer

    let hands = VisionHandClient()

    private var hasStarted = false

    func startHandTracking() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            // This *will* print as soon as the Task starts
            print("[HandDebugModel] calling VisionHandClient.run()")

            do {
                // Long-running; expect this to suspend for the lifetime of the app
                try await hands.run()

                // You usually WON'T see this unless the session ends
                print("[HandDebugModel] VisionHandClient.run() returned (session ended)")
            } catch {
                print("[HandDebugModel] VisionHandClient.run() error: \(error)")
            }
        }
    }

    func restartHandTrackingIfNeeded() {
        // If the session has ended or app became active again, attempt to run once more.
        Task { [weak self] in
            guard let self else { return }
            // If already running, VisionHandClient.run() should be long-lived; call again if it returned.
            print("[HandDebugModel] restartHandTrackingIfNeeded() invoked")
            do {
                try await self.hands.run()
                print("[HandDebugModel] VisionHandClient.run() returned (session ended)")
            } catch {
                print("[HandDebugModel] VisionHandClient.run() error on restart: \(error)")
            }
        }
    }
}


