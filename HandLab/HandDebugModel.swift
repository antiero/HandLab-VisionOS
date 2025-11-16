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
    @Published var followTranslation: Bool = true

    /// When in follow mode, whether to preserve real-world hand proximity
    /// (i.e. don't artificially separate left and right hands).
    @Published var absolutePositions: Bool = true

    /// Shared VisionHandClient used by the immersive view.
    let hands = VisionHandClient()
}
