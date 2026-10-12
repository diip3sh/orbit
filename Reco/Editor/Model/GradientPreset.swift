//
//  GradientPreset.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import Foundation

/// A pair of gradient colors the inspector offers. A preset isn't saved as such, only its colors, so
/// projects don't depend on this list.
nonisolated struct GradientPreset: Equatable, Identifiable, Sendable {
    let name: String
    let start: RGBAColor
    let end: RGBAColor

    var id: String { name }

    /// The default: a slate that stays out of the video's way.
    static let slate = GradientPreset("Slate", rgb(0.29, 0.32, 0.38), rgb(0.12, 0.13, 0.16))

    /// Each start is a color of the system palette in light mode (sRGB); the end is a darker shade picked
    /// by eye.
    static let all = [
        slate,
        GradientPreset("Graphite", rgb(0.20, 0.20, 0.22), rgb(0.05, 0.05, 0.06)),
        GradientPreset("Mist", rgb(0.90, 0.91, 0.93), rgb(0.70, 0.72, 0.76)),
        GradientPreset("Ocean", rgb(0.00, 0.48, 1.00), rgb(0.02, 0.16, 0.45)),
        GradientPreset("Indigo", rgb(0.35, 0.34, 0.84), rgb(0.13, 0.10, 0.38)),
        GradientPreset("Orchid", rgb(0.69, 0.32, 0.87), rgb(1.00, 0.18, 0.33)),
        GradientPreset("Sunset", rgb(1.00, 0.58, 0.00), rgb(1.00, 0.18, 0.33)),
        GradientPreset("Peach", rgb(1.00, 0.84, 0.70), rgb(0.98, 0.60, 0.55)),
        GradientPreset("Lagoon", rgb(0.19, 0.69, 0.78), rgb(0.00, 0.33, 0.52)),
        GradientPreset("Forest", rgb(0.20, 0.78, 0.35), rgb(0.03, 0.35, 0.24))
    ]

    private init(_ name: String, _ start: RGBAColor, _ end: RGBAColor) {
        self.name = name
        self.start = start
        self.end = end
    }

    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> RGBAColor {
        RGBAColor(red: red, green: green, blue: blue, alpha: 1)
    }
}
