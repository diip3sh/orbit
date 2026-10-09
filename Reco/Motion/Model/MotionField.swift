//
//  MotionField.swift
//  Reco
//

import Foundation

/// What a scene is drawn over: a lit, textured field coloured from the brand (``FieldPalette``), or
/// the canvas's plain background. The agent names one; how it looks is the field's. Paper's looks were
/// picked by eye from a gallery of twelve (spec 0012, Q2); the others are their shaders' other shapes.
nonisolated enum MotionField: String, Codable, CaseIterable, Sendable {
    /// Grain gradient pooling in two corners, the type in the dark gap between: bold brands.
    case ember
    /// A soft grain wave rising from below: calm or playful title cards.
    case sunlit
    /// Grain gradient in a blob that wanders round the middle.
    case bloom
    /// A grainy sphere lit from a turning light.
    case orb
    /// Grainy rings rippling out from the middle.
    case ripple
    /// A slowly lit sphere in ordered 4×4 dither: technical brands.
    case matrix
    /// Streaks of dither folding over each other like a liquid.
    case warp
    /// Dither in arms turning round the middle.
    case swirl
    /// A dithered wave filling the frame from below.
    case tide
    /// A ring of smoke round the middle: the end card's logo moment.
    case halo
    /// Black with the brand's gradient light round a dark middle, smooth, from a corner or two, in a new place
    /// every shot: Lovable's ground (spec 0015), under type and rebuilt UI alike.
    case aurora
    /// Black satin out of focus under one broad light, a lit plane's edge across a corner: dark,
    /// premium UI in macro (New Raycast's ground).
    case satin
    /// The canvas's background colour.
    case plain

    /// The visual languages a film keeps to (spec 0012: one language throughout, never a new technique a
    /// shot). Each has its own seam: the light's ``MotionSeam/glow``, the dither's ``MotionSeam/dither``.
    nonisolated enum Family: String, Sendable {
        /// Raycast's black satin and glass.
        case satin
        /// Paper's grain gradient: lit, grainy light in the brand's hue (GitHub Copilot X, Lovable).
        case light
        /// Paper's dithering: the brand's colour in ordered dots (Nothing OS, Vercel Ship).
        case dither
        /// Paper's smoke ring: a logo's moment, at home in any look but satin's.
        case smoke
        /// Lovable's smooth gradient light: cut, never a seam of its own.
        case aurora
        case plain
    }

    var family: Family {
        switch self {
        case .ember, .sunlit, .bloom, .orb, .ripple: .light
        case .matrix, .warp, .swirl, .tide: .dither
        case .halo: .smoke
        case .satin: .satin
        case .aurora: .aurora
        case .plain: .plain
        }
    }

    /// Paper's looks are pictures of their own: under a shot of type they compete with it (in a Linear
    /// film matrix's sphere sat in the middle of every frame, under the titles and through the panels).
    /// Under glass in macro, the glass blurs them into light.
    var isBusy: Bool {
        family == .light || family == .dither || family == .smoke
    }
}
