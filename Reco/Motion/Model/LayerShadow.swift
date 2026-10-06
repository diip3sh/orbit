//
//  LayerShadow.swift
//  Reco
//

import Foundation

/// A soft black shadow cast down onto the canvas, in canvas pixels.
nonisolated struct LayerShadow: Codable, Equatable, Sendable {
    var opacity: Double
    var radius: Double
    var offset: Double
}
