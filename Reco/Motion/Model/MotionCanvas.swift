//
//  MotionCanvas.swift
//  Reco
//

import CoreGraphics

/// The frame every scene is drawn in.
nonisolated struct MotionCanvas: Equatable, Sendable {
    var size = CGSize(width: 1920, height: 1080)

    /// Whole frames per second.
    var frameRate = 60

    /// Near-black, as the dark reference videos (mean luma 12.7–23.7); never pure black.
    var background = RGBAColor(red: 0.031, green: 0.035, blue: 0.039, alpha: 1)
}

// MARK: - Codable

nonisolated extension MotionCanvas: Codable {

    init(from decoder: any Decoder) throws {
        let defaults = MotionCanvas()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        size = try container.decodeIfPresent(CGSize.self, forKey: .size) ?? defaults.size
        frameRate = try container.decodeIfPresent(Int.self, forKey: .frameRate) ?? defaults.frameRate
        background = try container.decodeIfPresent(RGBAColor.self, forKey: .background) ?? defaults.background
    }
}
