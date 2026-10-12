//
//  AuroraSetup+Haze.swift
//  Reco
//

import Foundation

/// The haze (``MotionField/haze``): the aurora's soft lights on white, after two light AI launch reels
/// (`~/Movies/Reco/references/new/`). Vantae's is a deep blue blob, #0436e7 at its heart through #0b92f6, with a short pale
/// band (#cbecf8) into a white faintly tinted blue (#f5fbfd), sweeping round the frame; IrukaDark's a pastel orb, orange
/// (#f7ca91) ringed by pink (#e4b3cc) and lilac, in the middle of #fcfcfc.
nonisolated extension AuroraSetup {

    /// The shots' setups in turn: the orb behind the opening's type, a deep blob sweeping in from a corner, two faint corners
    /// under UI, a broad wash from below, the blob from the other side.
    static let haze = [
        AuroraSetup(lights: [
            Light(0.5, 0.52, radius: 0.36, strength: 0.5, elongation: 1.2, angle: 20),
            Light(0.54, 0.46, radius: 0.2, strength: 0.3)
        ]),
        AuroraSetup(lights: [
            Light(-0.05, 0.95, radius: 0.42, strength: 2.4, elongation: 2.1, angle: -58),
            Light(0.18, 0.2, radius: 0.22, strength: 0.6, elongation: 2.4, angle: -70)
        ]),
        AuroraSetup(lights: [
            Light(1.02, -0.02, radius: 0.36, strength: 0.48, elongation: 2.2, angle: -25),
            Light(-0.02, 1.04, radius: 0.36, strength: 0.42, elongation: 2.2, angle: -25)
        ]),
        AuroraSetup(lights: [
            Light(0.45, 1.25, radius: 0.5, strength: 0.75, elongation: 3, angle: 5)
        ]),
        AuroraSetup(lights: [
            Light(1.05, 0.1, radius: 0.42, strength: 2.2, elongation: 2.1, angle: 55),
            Light(0.85, 0.9, radius: 0.2, strength: 0.5, elongation: 2.5, angle: 60)
        ])
    ]

    static func haze(_ index: Int) -> AuroraSetup {
        haze[index % haze.count]
    }

    /// How far and how fast the haze's lights wander against the aurora's, swinging round as they go: Vantae's blob turns
    /// about 45° in 2 s, its edge crossing a fifth of the frame a second, where Lovable's light barely moves within a shot.
    static let hazeDrift = (reach: 6.0, rate: 5.0)

    /// The ramp's stops from white into the gradient's first colour, as shares of the way there in lightness (chroma follows
    /// on a curve, so the pale band stays pale), and the gradient across ``hazeSpan``: a faint light is a tint of white, a
    /// strong one's heart the gradient's last colour.
    static let hazeCore = [(position: 0.0, share: 0.0), (position: 0.1, share: 0.08), (position: 0.25, share: 0.3), (position: 0.42, share: 0.62)]
    static let hazeSpan = 0.55...0.95

    /// The white the haze lies on: almost paper, a breath of the gradient's first hue (Vantae's #f5fbfd).
    static let hazePaper = (lightness: 0.985, chroma: 0.006)
}
