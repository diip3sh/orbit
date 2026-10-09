//
//  StyleTokens.swift
//  Reco
//

import Foundation

/// The brand a document's shots are drawn in, from `inspect_page`'s `brand`: two products get
/// different videos from the same shot list without a dice roll. The background is the canvas's.
nonisolated struct StyleTokens: Equatable, Sendable {
    var text = RGBAColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)

    /// Secondary text: a subtitle, an address.
    var dim = RGBAColor(red: 0.55, green: 0.56, blue: 0.6, alpha: 1)

    /// The one accent: the end card's call to action, if the brand has one.
    var accent: RGBAColor?

    /// The brand's gradient, its colours in order (spec 0015): type runs them left to right, the aurora's light from
    /// the dark middle outwards. New words, a shimmer and a wash are drawn in it.
    var gradient: [RGBAColor]?

    var face = TextContent.Face.sans

    /// Where titles sit: on the left of the safe area, or centred.
    var alignment = TextContent.Alignment.leading
}

// MARK: - Codable

nonisolated extension StyleTokens: Codable {

    init(from decoder: any Decoder) throws {
        let defaults = StyleTokens()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(RGBAColor.self, forKey: .text) ?? defaults.text
        dim = try container.decodeIfPresent(RGBAColor.self, forKey: .dim) ?? defaults.dim
        accent = try container.decodeIfPresent(RGBAColor.self, forKey: .accent)
        gradient = try container.decodeIfPresent([RGBAColor].self, forKey: .gradient)
        face = try container.decodeIfPresent(TextContent.Face.self, forKey: .face) ?? defaults.face
        alignment = try container.decodeIfPresent(TextContent.Alignment.self, forKey: .alignment) ?? defaults.alignment
    }
}

// MARK: - The brand's gradient

nonisolated extension StyleTokens {

    /// The brand's gradient: its own, or three steps from the accent turning 35° at a time and lighter (sunlit's violet
    /// offset), or cool silver for a brand without a hue.
    var brandGradient: [RGBAColor] {
        if let gradient, gradient.count >= 2 {
            return gradient
        }
        let brand = accent.map(OKLCH.init)
        guard let brand, brand.chroma >= FieldPalette.leastBrandChroma else {
            return Self.silver.map { OKLCH(lightness: $0, chroma: FieldPalette.neutralChroma, hue: FieldPalette.neutralHue).rgba }
        }
        return (0..<3).map { step in
            let turn = Double(step) * 35
            return OKLCH(
                lightness: min(brand.lightness + 0.06 * Double(step), 0.85), chroma: brand.chroma, hue: (brand.hue + turn).truncatingRemainder(dividingBy: 360)
            ).rgba
        }
    }

    /// The silver gradient's lightness steps.
    static let silver = [0.55, 0.72, 0.9]
}
