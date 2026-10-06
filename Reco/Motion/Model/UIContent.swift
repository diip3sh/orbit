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
}
