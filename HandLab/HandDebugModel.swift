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
    @Published var followTranslation: Bool = false

    /// When in follow mode, whether to preserve real-world hand proximity.
    @Published var absolutePositions: Bool = false

    /// Left/right hand debug colors (SwiftUI Color for the control panel).
    @Published var leftHandColor: Color = .blue
    @Published var rightHandColor: Color = .red
    
    /// Bone (cylinder) color for both hands.
    @Published var boneColor: Color = .white

    /// Shared VisionHandClient used by the immersive view.
    let hands = VisionHandClient()
}
