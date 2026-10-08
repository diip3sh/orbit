//
//  LayerShadow.swift
//  Reco
//

import Foundation

/// A soft shadow cast down onto the canvas, in canvas pixels: black, or in `color`. In a colour with no
/// offset it's a glow, as motion design's green pills have (spec 0014).
nonisolated struct LayerShadow: Codable, Equatable, Sendable {
    var opacity: Double
    var radius: Double
    var offset: Double
    var color: RGBAColor?
}
