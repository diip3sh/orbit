//
//  SoundRules+Graphic.swift
//  Reco
//

import Foundation

/// The graphic seams' sounds (spec 0019), from the voices the story seams use: air where things move fastest, a glass where
/// the next scene shows, a soft low landing, bits where the frame steps.
nonisolated extension SoundRules {

    /// Air peaks where a graphic seam's edges are fastest (half way on its in-out curve).
    static let graphicSwish = (length: 0.4, level: -21.0, send: 0.25, at: 0.3)

    /// A bar or slat lands with a short low hit, quieter for each that follows.
    static let barLanding = (high: 76.0, low: 46.0, length: 0.35, decay: 0.1, level: -23.0, step: 3.0)

    /// An iris or liquid opens with air rising into it and a glass as the next scene shows inside.
    static let openRiser = (length: 0.45, low: 700.0, high: 6000.0, power: 1.8, level: -22.0, peak: 0.45)
    static let openGlass = (note: 91.0, length: 1.2, brightness: 1.15, level: -25.0, at: 0.6)

    /// A spin, split or stretch has a whoosh at the cut.
    static let graphicWhoosh = -15.0

    /// A flash is a hit: a low thump and a bright glass on its peak.
    static let flashThump = (high: 90.0, low: 40.0, length: 0.7, decay: 0.16, level: -17.0)
    static let flashGlass = (note: 96.0, length: 1.0, brightness: 1.4, level: -24.0)
}
