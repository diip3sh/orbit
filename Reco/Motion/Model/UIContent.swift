//
//  UIContent.swift
//  Reco
//

import Foundation

/// A `ui` layer: the element an asset lifts, at its own aspect ratio.
nonisolated struct UIContent: Codable, Equatable, Sendable {

    /// A ``MotionAsset``'s id.
    var asset: String

    /// In canvas pixels; when left out, the element's CSS width, so a CSS pixel is a canvas pixel.
    var width: Double?

    /// The lift drawn in this one colour through its alpha: a brand's mark (black as published) made white on a
    /// coloured tile. Left out, its own colours.
    var tint: RGBAColor?

    /// When the asset's text starts being typed, in seconds into the scene; before, its field shows
    /// empty with the caret blinking. Left out, it's never typed.
    var typingStart: Double?

    /// The arrow keys pressed in a typed field's results, moving its selection through those the
    /// asset lifted selected; the scene's camera follows the selected result a beat late.
    var presses: [Press]?

    nonisolated enum ArrowKey: String, Codable, Sendable {
        case arrowDown = "down", arrowUp = "up"
    }

    nonisolated struct Press: Codable, Equatable, Sendable {
        var key: ArrowKey

        /// Seconds into the scene.
        var time: Double
    }
}
