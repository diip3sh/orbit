//
//  LayerTint.swift
//  Reco
//

import Foundation

/// The brand's gradient over a layer's pixels for a while (spec 0015): a shimmer runs through them as their colour, a
/// wash sweeps across the layer ``over`` and its group's layers, lightening them.
nonisolated struct LayerTint: Sendable {

    nonisolated enum Kind: Sendable {
        case shimmer, wash
    }

    let kind: Kind
    let start: Double
    let duration: Double

    /// The layer whose bounds, its group's layers' included, a wash sweeps across.
    let over: Int
}
