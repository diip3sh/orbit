//
//  ImageContent.swift
//  Reco
//

import CoreGraphics

/// An image layer: a file in the bundle's `assets/` shown at `size` canvas pixels.
nonisolated struct ImageContent: Codable, Equatable, Sendable {

    /// Relative to the bundle, e.g. `assets/card.png`.
    var path: String

    var size: CGSize
}
