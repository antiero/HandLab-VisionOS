//
//  HandDebugModel.swift
//  HandLab
//
//  Created by Antony Nasce on 16/11/2025.
//

import Foundation
import Combine
import SwiftUI
import VisionHandKit

@MainActor
final class HandDebugModel: ObservableObject {

    /// Whether the tiny hands should move around in the debug volume.
    @Published var followTranslation: Bool = true

    /// When in follow mode, whether to preserve real-world hand proximity.
    @Published var absolutePositions: Bool = true

    /// Left/right hand debug colors (SwiftUI Color for the control panel).
    @Published var leftHandColor: Color = .blue
    @Published var rightHandColor: Color = .red
    
    /// Bone (cylinder) color for both hands.
    @Published var boneColor: Color = .white
    
    /// Joint sphere radius (in metres, scene scale).
    @Published var jointRadius: Double = 0.004

    /// Bone cylinder radius (in metres, scene scale).
    @Published var boneRadius: Double = 0.002

    /// Shared VisionHandClient used by the immersive view.
    let hands = VisionHandClient()
}
