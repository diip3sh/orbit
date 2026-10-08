//
//  ScreenshotBackground.swift
//  Reco
//

import Foundation

/// How a screenshot is put on a background from the card (spec 0004, N14): the editor's canvas style, in the shot's
/// own shape, and whether the shot's uniform borders are trimmed first so the padding is even around what matters.
nonisolated struct ScreenshotBackground: Codable, Equatable, Sendable {

    /// The shape is always the shot's own; the picture, padding, corners, shadow and border are the user's.
    var canvas = CanvasStyle()

    /// Auto Balance: trim the borders of one colour around the content before padding it.
    var autoBalances = true

    /// The canvas as the shot is laid out in: its own shape, fitted.
    var layoutStyle: CanvasStyle {
        var style = canvas
        style.aspect = .source
        style.fillsFrame = false
        return style
    }
}

// MARK: - Decoding

extension ScreenshotBackground {

    /// Settings added later take their defaults when missing.
    nonisolated init(from decoder: any Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        canvas = try container.decodeIfPresent(CanvasStyle.self, forKey: .canvas) ?? canvas
        autoBalances = try container.decodeIfPresent(Bool.self, forKey: .autoBalances) ?? autoBalances
    }
}
