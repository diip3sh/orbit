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
    /// Black satin out of focus under one broad light, a lit plane's edge across a corner: dark,
    /// premium UI in macro (New Raycast's ground).
    case satin
    /// The canvas's background colour.
    case plain
}

nonisolated extension MotionField {

    /// Paper's looks, pictures of their own: the user rejected them as pasted behind the video, and in
    /// a Linear film matrix's sphere sat in the middle of every frame, under the titles and through
    /// the panels. Documents may still name them; the agent isn't offered them.
    var isBusy: Bool {
        [.ember, .matrix, .halo, .sunlit].contains(self)
    }
}
