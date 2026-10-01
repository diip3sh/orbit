//
//  ExportSettings.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics

/// How an edited video is exported: its codec, size and frame rate.
nonisolated struct ExportSettings: Equatable, Sendable {
    var format = ExportFormat.hevc

    /// The output's shorter side in pixels, or `nil` for the canvas's own.
    var resolution: Int?

    /// Frames per second, or `nil` for the recording's.
    var frameRate: Int?

    /// The shorter sides offered for a canvas whose shorter side is `shorterSide`: only smaller ones.
    static func resolutions(below shorterSide: CGFloat) -> [Int] {
        [2160, 1440, 1080, 720].filter { CGFloat($0) < shorterSide }
    }

    /// The frame rates offered for a recording at `frameRate`: only lower ones.
    static func frameRates(below frameRate: Double) -> [Int] {
        [60, 30, 24].filter { Double($0) < frameRate.rounded() }
    }
}
