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
    private var runTask: Task<Void, Never>? = nil

    private var hasStarted = false

    func startHandTracking() {
        // Avoid spawning multiple run loops
        guard runTask == nil else { return }
        hasStarted = true

        runTask = Task { [weak self] in
            guard let self else { return }
            print("[HandDebugModel] calling VisionHandClient.run()")
            defer {
                // Mark not started so we can start again later
                Task { @MainActor in
                    self.hasStarted = false
                    self.runTask = nil
                }
            }
            do {
                try await self.hands.run()
                print("[HandDebugModel] VisionHandClient.run() returned (session ended)")
            } catch {
                print("[HandDebugModel] VisionHandClient.run() error: \(error)")
            }
        }
    }

    func restartHandTrackingIfNeeded() {
        // If not currently running, start again. Safe to call multiple times.
        if runTask == nil {
            startHandTracking()
        } else {
            print("[HandDebugModel] restartHandTrackingIfNeeded(): runTask already active")
        }
    }

    func stopHandTracking() {
        // Cancel the running task, if any, so ARKit session/providers stop cleanly
        if let task = runTask {
            print("[HandDebugModel] Cancelling hand tracking task")
            task.cancel()
            runTask = nil
        }
        hasStarted = false
    }
}

