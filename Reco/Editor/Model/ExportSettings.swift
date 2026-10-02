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

    /// The shorter sides offered for a canvas whose shorter side is `shorterSide`: only smaller
    /// ones, and small ones for GIF, whose files are large.
    static func resolutions(below shorterSide: CGFloat, for format: ExportFormat = .hevc) -> [Int] {
        (format == .gif ? [720, 540, 360] : [2160, 1440, 1080, 720]).filter { CGFloat($0) < shorterSide }
    }

    /// The frame rates offered for a recording at `frameRate`: only lower ones. GIF stores delays
    /// in hundredths of a second, so it plays in time only at 50 and 25.
    static func frameRates(below frameRate: Double, for format: ExportFormat = .hevc) -> [Int] {
        format == .gif ? [50, 25].filter { Double($0) <= frameRate.rounded() || $0 == 25 } : [60, 30, 24].filter { Double($0) < frameRate.rounded() }
    }

    /// These settings with a size and frame rate their format offers for a canvas whose shorter
    /// side is `shorterSide`, recorded at `frameRate`: the original for a video and 540 pixels at
    /// 25 fps for a GIF, unless one that is offered is chosen.
    func conformed(shorterSide: CGFloat, frameRate: Double) -> ExportSettings {
        var settings = self
        let resolutions = Self.resolutions(below: shorterSide, for: format)
        let frameRates = Self.frameRates(below: frameRate, for: format)
        if resolution.map(resolutions.contains) != true {
            settings.resolution = format == .gif && resolutions.contains(540) ? 540 : nil
        }
        if self.frameRate.map(frameRates.contains) != true {
            settings.frameRate = format == .gif ? 25 : nil
        }
        return settings
    }
}
