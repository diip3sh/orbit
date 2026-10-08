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

    /// In a shape other than the recording's, whether the video covers the space inside the padding instead of
    /// fitting in it: the camera shows the largest part of the video in that shape and follows the cursor with
    /// it (see ``CanvasLayout/baseView``). Nothing in the recording's own shape.
    var fillsFrame = false

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
    var gradientStart = GradientPreset.slate.start
    var gradientEnd = GradientPreset.slate.end

    /// A security-scoped bookmark to the picture the user chose for an ``Background/image`` background.
    var imageBookmark: Data?

    /// How much an image background is blurred, from 0 (sharp) to 1 (see ``CanvasLayout/maximumBackgroundBlur``).
    var backgroundBlur = 0.0

    /// A frame around the video, as a share of the frame's shorter side; 0 is none.
    var borderWidth = 0.0
    var borderColor = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)

    /// The preset the gradient's colors are, or `nil` when they were picked by hand.
    var gradientPreset: GradientPreset? {
        GradientPreset.all.first { $0.start == gradientStart && $0.end == gradientEnd }
    }

    /// Whether the video covers the padded space: ``fillsFrame`` in a shape that isn't the recording's.
    var fills: Bool {
        fillsFrame && aspect != .source
    }

    /// Makes `preset` the gradient: both colors at once, so a bound control's one write is one edit.
    mutating func apply(_ preset: GradientPreset) {
        gradientStart = preset.start
        gradientEnd = preset.end
    }

    /// Makes the picture `bookmark` opens the background.
    mutating func setImage(_ bookmark: Data) {
        background = .image
        imageBookmark = bookmark
    }

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

// MARK: - Decoding

extension CanvasStyle {

    /// Settings added after a project was saved take their defaults when missing.
    nonisolated init(from decoder: any Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        aspect = try container.decodeIfPresent(Aspect.self, forKey: .aspect) ?? aspect
        fillsFrame = try container.decodeIfPresent(Bool.self, forKey: .fillsFrame) ?? fillsFrame
        padding = try container.decodeIfPresent(Double.self, forKey: .padding) ?? padding
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? cornerRadius
        shadow = try container.decodeIfPresent(Double.self, forKey: .shadow) ?? shadow
        background = try container.decodeIfPresent(Background.self, forKey: .background) ?? background
        color = try container.decodeIfPresent(RGBAColor.self, forKey: .color) ?? color
        gradientStart = try container.decodeIfPresent(RGBAColor.self, forKey: .gradientStart) ?? gradientStart
        gradientEnd = try container.decodeIfPresent(RGBAColor.self, forKey: .gradientEnd) ?? gradientEnd
        imageBookmark = try container.decodeIfPresent(Data.self, forKey: .imageBookmark)
        backgroundBlur = try container.decodeIfPresent(Double.self, forKey: .backgroundBlur) ?? backgroundBlur
        borderWidth = try container.decodeIfPresent(Double.self, forKey: .borderWidth) ?? borderWidth
        borderColor = try container.decodeIfPresent(RGBAColor.self, forKey: .borderColor) ?? borderColor
    }
}
