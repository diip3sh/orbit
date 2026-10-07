//
//  FieldPalette.swift
//  Reco
//

import Foundation

/// A field's colours, from the brand by rule, never set by hand (spec 0012, Q2). Each stop keeps
/// the lightness it had in the gallery the looks were picked from and its hue's offset from the
/// lead colour's; the lead takes the brand's hue, and its chroma up to the picked one's. A brand
/// without a hue (a white or grey accent, or none) gets the same steps in cool greys.
nonisolated struct FieldPalette: Equatable, Sendable {
    /// What the stops lie on.
    var back: RGBAColor

    /// In the order the field's shader takes them.
    var colors: [RGBAColor]

    init(_ field: MotionField, accent: RGBAColor?, background: RGBAColor) {
        guard let look = Self.looks[field] else {
            back = background
            colors = []
            return
        }
        let brand = accent.map(OKLCH.init)
        let hasHue = (brand?.chroma ?? 0) >= Self.leastBrandChroma
        let hue = hasHue ? brand?.hue ?? Self.neutralHue : Self.neutralHue
        let lead = hasHue ? min(brand?.chroma ?? 0, look.leadChroma) : Self.neutralChroma
        let color = { (stop: Stop) in
            OKLCH(lightness: stop.lightness, chroma: lead * stop.chromaShare, hue: (hue + stop.hueOffset + 360).truncatingRemainder(dividingBy: 360)).rgba
        }
        back = color(look.back)
        colors = look.stops.map(color)
    }

    /// Below this chroma an accent reads as white or grey (Linear's #e5e5e6 is 0.002).
    static let leastBrandChroma = 0.03

    /// Cool greys for brands without a hue.
    static let neutralHue = 265.0
    static let neutralChroma = 0.02

    /// A stop as picked: its OKLCH lightness, its chroma as a share of the lead's, and its hue's
    /// offset from the lead's in degrees.
    nonisolated struct Stop: Sendable {
        let lightness: Double
        let chromaShare: Double
        let hueOffset: Double
    }

    nonisolated struct Look: Sendable {
        /// The lead stop's chroma in the gallery: a brand's is used up to this.
        let leadChroma: Double
        let back: Stop
        let stops: [Stop]
    }

    /// The gallery's palettes in OKLCH, each relative to its lead colour:
    /// - ember #050405 under #ff3b2f, #8a1414, #2a0c12;
    /// - matrix #2f9e6c on #060907;
    /// - halo #ffffff, #3ecf8e on black;
    /// - sunlit #c4730b, #bdad5f, #d8ccc7 on #140c04;
    /// - satin white light on black, never tinted: New Raycast's is monochrome.
    static let looks: [MotionField: Look] = [
        .ember: Look(
            leadChroma: 0.232, back: Stop(lightness: 0.110, chromaShare: 0.022, hueOffset: 0),
            stops: [Stop(lightness: 0.654, chromaShare: 1, hueOffset: 0), Stop(lightness: 0.409, chromaShare: 0.655, hueOffset: -1.5),
                    Stop(lightness: 0.206, chromaShare: 0.216, hueOffset: -18.6)]
        ),
        .matrix: Look(
            leadChroma: 0.125, back: Stop(lightness: 0.135, chromaShare: 0.064, hueOffset: -2.3),
            stops: [Stop(lightness: 0.624, chromaShare: 1, hueOffset: 0)]
        ),
        .halo: Look(
            leadChroma: 0.154, back: Stop(lightness: 0, chromaShare: 0, hueOffset: 0),
            stops: [Stop(lightness: 1, chromaShare: 0, hueOffset: 0), Stop(lightness: 0.762, chromaShare: 1, hueOffset: 0)]
        ),
        .sunlit: Look(
            leadChroma: 0.141, back: Stop(lightness: 0.162, chromaShare: 0.163, hueOffset: 7.3),
            stops: [Stop(lightness: 0.631, chromaShare: 1, hueOffset: 0), Stop(lightness: 0.744, chromaShare: 0.716, hueOffset: 35.1),
                    Stop(lightness: 0.854, chromaShare: 0.106, hueOffset: -18.7)]
        ),
        .satin: Look(leadChroma: 0, back: Stop(lightness: 0, chromaShare: 0, hueOffset: 0), stops: [Stop(lightness: 1, chromaShare: 0, hueOffset: 0)])
    ]
}
