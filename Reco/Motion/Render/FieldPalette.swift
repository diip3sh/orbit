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

    /// `field`'s colours in `style`: the aurora's are its dark middle's stops into the brand's gradient
    /// (``AuroraSetup/core``), the others' from the accent.
    init(_ field: MotionField, style: StyleTokens, background: RGBAColor) {
        guard field == .aurora else {
            self.init(field, accent: style.accent, background: background)
            return
        }
        let gradient = style.brandGradient
        let first = OKLCH(gradient[0])
        // The navy climbs to the gradient's first colour and never past it: a darker first colour made the ramp dip, and
        // two lights meeting drew a thin bright line
        let climb = min(first.lightness / (AuroraSetup.core.last?.lightness ?? 1), 1)
        let core = AuroraSetup.core.map { OKLCH(lightness: $0.lightness * climb, chroma: first.chroma * $0.chromaShare, hue: first.hue).rgba }
        self.init(back: RGBAColor(red: 0, green: 0, blue: 0, alpha: 1), colors: core + gradient)
    }

    private init(back: RGBAColor, colors: [RGBAColor]) {
        self.back = back
        self.colors = colors
    }

    init(_ field: MotionField, accent: RGBAColor?, background: RGBAColor) {
        if field == .aurora {
            self.init(field, style: StyleTokens(accent: accent), background: background)
        } else if let look = Self.look(for: field) {
            let brand = accent.map(OKLCH.init)
            let hasHue = (brand?.chroma ?? 0) >= Self.leastBrandChroma
            let hue = hasHue ? brand?.hue ?? Self.neutralHue : Self.neutralHue
            let lead = hasHue ? min(brand?.chroma ?? 0, look.leadChroma) : Self.neutralChroma
            let color = { (stop: Stop) in
                OKLCH(lightness: stop.lightness, chroma: lead * stop.chromaShare, hue: (hue + stop.hueOffset + 360).truncatingRemainder(dividingBy: 360)).rgba
            }
            self.init(back: color(look.back), colors: look.stops.map(color))
        } else {
            self.init(back: background, colors: [])
        }
    }

    /// The picked palette `field` takes: Paper's other shapes take their shader's pick's, the grain's
    /// sunlit's three hues (in bolt.new's blue, the lead, a violet and a pale grey: the user's favourite
    /// ground; ember's one hue drew its blob and rings flat).
    static func look(for field: MotionField) -> Look? {
        switch field {
        case .bloom, .orb, .ripple: looks[.sunlit]
        case .warp, .swirl, .tide: looks[.matrix]
        default: looks[field]
        }
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
