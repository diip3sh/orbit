//
//  CanvasStyle.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import Foundation

/// The frame the recording is shown in: its shape, the background around the video, and the
/// video's padding, corners and shadow.
nonisolated struct CanvasStyle: Codable, Equatable, Sendable {
    var aspect = Aspect.source

    /// The space around the video, as a share of the frame's shorter side.
    var padding = 0.08

    /// The video's corner radius, as a share of the frame's shorter side.
    var cornerRadius = 0.015

    /// How dark the video's shadow is, from 0 (none) to 1.
    var shadow = 0.5

    var background = Background.gradient

    /// The color of a ``Background/color`` background, and of an image one without its image.
    var color = RGBAColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)

    /// A gradient's colors, from the top-left corner to the bottom-right.
    var gradientStart = RGBAColor(red: 0.29, green: 0.32, blue: 0.38, alpha: 1)
    var gradientEnd = RGBAColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1)

    /// A security-scoped bookmark to the picture the user chose for an ``Background/image`` background.
    var imageBookmark: Data?

    /// The recording as it is: its own shape, filling the frame.
    static let plain = CanvasStyle(aspect: .source, padding: 0, cornerRadius: 0, shadow: 0)

    nonisolated enum Aspect: String, Codable, CaseIterable, Sendable {
        case source
        case landscape = "16:9"
        case portrait = "9:16"
        case square = "1:1"
        case standard = "4:3"

        /// Width over height, or `nil` for the recording's own.
        var ratio: Double? {
            switch self {
            case .source: nil
            case .landscape: 16.0 / 9
            case .portrait: 9.0 / 16
            case .square: 1
            case .standard: 4.0 / 3
            }
        }
    }

    nonisolated enum Background: String, Codable, CaseIterable, Sendable {
        case gradient
        case color
        case image

        /// Only ProRes 4444 exports keep it; the other formats export it black.
        case transparent
    }
}
