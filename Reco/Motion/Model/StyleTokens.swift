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

    /// The brand's family every text is set in unless it names its own or is code (``MotionDocument/fonts``, spec 0019).
    var font: String?
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
        font = try container.decodeIfPresent(String.self, forKey: .font)
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

// MARK: - A graphic seam's colours

nonisolated extension StyleTokens {

    /// The two colours a graphic seam's bars, discs and blobs are drawn in (spec 0019): the accent (else the gradient's first),
    /// then the gradient's other end, or for a brand of one colour, that colour a quarter lighter (darker if it's light), so a
    /// seam is always the brand's.
    var seamColors: [RGBAColor] {
        let first = accent ?? brandGradient[0]
        if let gradient, gradient.count >= 2, let last = gradient.last {
            return [first, last == first ? gradient[0] : last]
        }
        var tint = OKLCH(first)
        tint.lightness += tint.lightness > 0.6 ? -Self.seamTint : Self.seamTint
        return [first, tint.rgba]
    }

    /// How much lighter or darker a one-colour brand's second seam colour is, in OKLCH lightness.
    static let seamTint = 0.25

    /// ``seamColors`` for a seam between scenes on `grounds`: the brand's two kept while they stand out from both, else the
    /// farthest of them, the text's colour and `background`. An accent bar over a scene already on the accent was lost.
    func seamColors(between grounds: [RGBAColor], background: RGBAColor) -> [RGBAColor] {
        let brand = seamColors
        guard !grounds.isEmpty else { return brand }
        let apart = { (color: RGBAColor) in grounds.map { Self.difference(color, $0) }.min() ?? 1 }
        let kept = brand.filter { apart($0) >= Self.seamContrast }
        let others = (brand + [text, background]).filter { !kept.contains($0) }.sorted { apart($0) > apart($1) }
        return Array((kept + others).prefix(2))
    }

    /// How far apart in OKLab a seam's colour and a ground must be to tell them apart at a glance.
    static let seamContrast = 0.15

    private static func difference(_ one: RGBAColor, _ other: RGBAColor) -> Double {
        let (first, second) = (OKLCH(one), OKLCH(other))
        let opponent = { (color: OKLCH) in (color.chroma * cos(color.hue * .pi / 180), color.chroma * sin(color.hue * .pi / 180)) }
        let (start, end) = (opponent(first), opponent(second))
        return ((first.lightness - second.lightness) * (first.lightness - second.lightness)
            + (start.0 - end.0) * (start.0 - end.0) + (start.1 - end.1) * (start.1 - end.1)).squareRoot()
    }
}
