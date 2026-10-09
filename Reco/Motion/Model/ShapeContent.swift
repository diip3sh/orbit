//
//  ShapeContent.swift
//  Reco
//

import CoreGraphics

/// A filled rounded rectangle, generated at any scale without a bitmap; or a triangle or a glyph drawn in its
/// colour, for motion design's particles and icons (spec 0014).
nonisolated struct ShapeContent: Equatable, Sendable {

    nonisolated enum Kind: String, Codable, CaseIterable, Sendable {
        case rectangle

        /// Filled, pointing up: a burst's particles.
        case triangle

        /// Glyphs stroked in the colour, ``ShapeContent/stroke`` wide (a tenth of the size by default). Drawn here
        /// rather than taken from SF Symbols, whose licence doesn't cover other products' films.
        case plus, check, cross, arrow, search, play, pause
        /// UI glyphs for story films (spec 0015): a dropdown's chevron (pointing down), a microphone, a terminal's prompt, a
        /// git branch.
        case chevron, mic, terminal, branch
    }

    var kind = Kind.rectangle
    var size: CGSize
    var cornerRadius = 0.0
    var color: RGBAColor

    /// A rectangle's outline this many canvas pixels wide instead of its fill; a glyph's line width.
    var stroke: Double?

    /// Whether it's drawn by ``kind``'s path rather than generated as a rounded rectangle.
    var isGlyph: Bool {
        kind != .rectangle
    }
}

// MARK: - Codable

nonisolated extension ShapeContent: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind, size, cornerRadius, color, stroke
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .rectangle
        size = try container.decode(CGSize.self, forKey: .size)
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 0
        color = try container.decode(RGBAColor.self, forKey: .color)
        stroke = try container.decodeIfPresent(Double.self, forKey: .stroke)
    }

    /// A rectangle leaves its kind out, as documents written before kinds did.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if kind != .rectangle {
            try container.encode(kind, forKey: .kind)
        }
        try container.encode(size, forKey: .size)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(color, forKey: .color)
        try container.encodeIfPresent(stroke, forKey: .stroke)
    }
}
