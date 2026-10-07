//
//  MotionField.swift
//  Reco
//

import Foundation

/// What a scene is drawn over: a lit, textured field coloured from the brand (``FieldPalette``), or
/// the canvas's plain background. The agent names one; how it looks is the field's, picked by eye
/// from a gallery of twelve (spec 0012, Q2).
nonisolated enum MotionField: String, Codable, CaseIterable, Sendable {
    /// Grain gradient pooling in two corners, the type in the dark gap between: bold brands.
    case ember
    /// A slowly lit sphere in ordered 4×4 dither: technical brands.
    case matrix
    /// A ring of smoke round the middle: the end card's logo moment.
    case halo
    /// A soft grain wave rising from below: calm or playful title cards.
    case sunlit
    /// The canvas's background colour.
    case plain
}
