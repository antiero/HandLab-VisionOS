//
//  HandDebugModel.swift
//  HandLab
//
//  Created by Antony Nasce on 16/11/2025.
//

import Foundation
import VisionHandKit
import Combine

@MainActor
final class HandDebugModel: ObservableObject {
    /// Whether the tiny hands should move around in the debug volume.
    @Published var followTranslation: Bool = false

    /// Shared VisionHandClient used by the immersive view.
    let hands = VisionHandClient()
}
