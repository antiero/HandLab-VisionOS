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
    var followTranslation: Bool = false
    var absolutePositions: Bool = false

    var leftHandColor: Color = .blue
    var rightHandColor: Color = .red
    var boneColor: Color = .white

    var jointRadius: Double = 0.004
    var boneRadius: Double = 0.002

    let hands = VisionHandClient()
}
