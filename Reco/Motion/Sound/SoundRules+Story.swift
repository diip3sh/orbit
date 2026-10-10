//
//  SoundRules+Story.swift
//  Reco
//

import Foundation

/// A story film's transition sounds (spec 0015). The user found a drum and bass bed under every cut "too punchy and weird,
/// the same sound everywhere", and asked for transition sounds: each transition has its own, over the quiet chords.
nonisolated extension SoundRules {

    /// A dither seam: its dots as blips, then where the next scene resolves (at this share of the seam) a struck glass and a
    /// soft low hit.
    static let bitsLevel = -21.0
    static let ditherLanding = (at: 0.85, note: 88.0, length: 1.2, brightness: 0.9, level: -24.0)
    static let ditherThump = (high: 80.0, low: 46.0, length: 0.6, decay: 0.14, level: -20.0)

    /// A glow seam: air rising into its brightest moment (this share of the seam), and a glass as the next scene shows.
    static let glowRiser = (length: 0.5, low: 500.0, high: 5000.0, power: 2.0, level: -22.0, peak: 0.45)
    static let glowGlass = (note: 86.0, length: 1.4, brightness: 1.1, level: -23.0)

    /// The ring into the logo: a swell into the cut, a deep hit on it, and a chord of glasses ringing out under the logo.
    static let ringRiser = (length: 1.2, low: 300.0, high: 6000.0, power: 2.4, level: -16.0)
    static let ringThump = (high: 66.0, low: 34.0, length: 2.0, decay: 0.5, level: -9.0)
    static let ringGlass = (notes: [74.0, 81, 86], levels: [-20.0, -23, -26], pans: [-0.15, 0.1, 0.2], length: 2.8, delay: 0.08)

    /// A wash: a bright shimmer rising with its front to where it has crossed (this far into it), a high glass as it does.
    static let washShimmer = (length: 0.55, low: 2000.0, high: 10000.0, power: 1.6, level: -22.0, crossed: 0.62)
    static let washGlass = (note: 98.0, length: 1.0, brightness: 1.4, level: -27.0)

    /// A stack: air as the card comes up, a soft low landing as it covers the frame (this share of the seam).
    static let stackSwish = (length: 0.45, level: -20.0, send: 0.25)
    static let stackLanding = (at: 0.6, high: 70.0, low: 44.0, length: 0.5, decay: 0.12, level: -24.0)

    /// An expand: air opening out into its brightest moment (this share of the seam), a glass as the next scene fills the frame.
    static let expandRiser = (length: 0.4, low: 800.0, high: 7000.0, power: 1.8, level: -22.0, peak: 0.35)
    static let expandGlass = (note: 93.0, length: 1.2, brightness: 1.2, level: -25.0)

    /// A story film's cut: its swish this much quieter, no hit.
    static let softCut = -3.0

    /// A swap to done (a status turning to Passed, Merge to Merged): two blips up a fourth, once however many layers swap.
    static let doneChime = (notes: [88.0, 93], gap: 0.07, levels: [-19.0, -21], length: 0.35)
    static let swapTogether = 0.05
}
