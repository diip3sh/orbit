//
//  LensPicture+Setup.swift
//  Reco
//

import Foundation

/// How each picture is drawn: four soft lights read through a ramp of four colours, fitted to one of the film's pictures at
/// 1080p in OKLab with its type and UI masked out (0.003–0.018 mean error), then grained and streaked as it was.
nonisolated extension LensPicture {

    /// A soft light: its middle in fractions of the picture from its top-left, its radius across in picture heights, its
    /// strength, how much longer it runs along its `angle` (degrees, clockwise from across).
    nonisolated struct Light: Equatable, Sendable {
        var center: CGPoint
        var radius: Double
        var strength: Double
        var elongation: Double
        var angle: Double

        init(_ across: Double, _ down: Double, radius: Double, strength: Double, elongation: Double, angle: Double) {
            center = CGPoint(x: across, y: down)
            (self.radius, self.strength, self.elongation, self.angle) = (radius, strength, elongation, angle)
        }
    }

    nonisolated struct Setup: Equatable, Sendable {
        var lights: [Light]

        /// The ramp's colours from no light to the most, the middle two at `places` of the way (the ends at 0 and 1), mixed in
        /// OKLab.
        var stops: [RGBAColor]
        var places: [Double]

        /// Grain in levels of 255 in the mid-tones, as the film's frames had it after its encoding (2–3 in its sand, 7–7.6 in
        /// its rose and indigo).
        var grain: Double

        /// How strongly the picture is streaked, and the streaks' direction (degrees, clockwise from across).
        var streaks = 0.0
        var streakAngle = 0.0
    }

    /// Grain in clumps about this wide at 1080p: neighbouring pixels of the film's grain correlated 0.74–0.89.
    static let grainClump = 2.2

    /// How far a picture's lights drift (picture heights) and how fast, so a held picture breathes as a camera on it would.
    static let drift = (reach: 0.02, rate: 0.6)

    var setup: Setup {
        switch self {
        case .sky: Setup(lights: [
            Light(0.972, 0.845, radius: 0.617, strength: 0.977, elongation: 1.73, angle: -8.1),
            Light(0.933, -0.088, radius: 0.517, strength: 0.842, elongation: 1.82, angle: -9.3),
            Light(0.727, 1.800, radius: 0.119, strength: 0.186, elongation: 7.74, angle: 63.5),
            Light(0.264, 0.847, radius: 0.108, strength: 0.124, elongation: 7.96, angle: -26.2)
        ], stops: Self.colors("#003445", "#365d88", "#5588a2", "#c1ccce"), places: [0.497, 0.759], grain: 5, streaks: 0.05, streakAngle: -30)
        case .violet: Setup(lights: [
            Light(-0.464, 1.271, radius: 0.299, strength: 1.244, elongation: 3.86, angle: -32.0),
            Light(-0.467, 0.833, radius: 0.155, strength: 0.986, elongation: 5.29, angle: -44.8),
            Light(0.314, 0.455, radius: 0.151, strength: 0.385, elongation: 3.73, angle: -39.5),
            Light(0.216, 1.001, radius: 0.080, strength: 0.285, elongation: 5.32, angle: -29.2)
        ], stops: Self.colors("#b7c7ca", "#b1c2c9", "#464c83", "#391a32"), places: [0.093, 0.618], grain: 5, streaks: 0.1, streakAngle: -38)
        case .dune: Setup(lights: [
            Light(-0.264, 1.388, radius: 0.472, strength: 0.820, elongation: 5.85, angle: -16.5),
            Light(-0.625, 1.797, radius: 0.295, strength: 0.669, elongation: 6.18, angle: -61.2),
            Light(0.589, 0.258, radius: 0.352, strength: 0.281, elongation: 1.35, angle: -33.4),
            Light(0.136, 0.673, radius: 0.284, strength: 0.153, elongation: 9.53, angle: 32.9)
        ], stops: Self.colors("#a7c0c6", "#d3cbb8", "#d8cab1", "#cfad69"), places: [0.339, 0.379], grain: 3, streaks: 0.15, streakAngle: -4)
        case .petal: Setup(lights: [
            Light(-0.702, 1.458, radius: 0.294, strength: 2.816, elongation: 3.98, angle: -53.8),
            Light(1.202, 0.031, radius: 0.622, strength: 0.800, elongation: 1.27, angle: -1.3),
            Light(0.270, 0.898, radius: 0.222, strength: 0.614, elongation: 1.70, angle: 33.5),
            Light(0.337, 0.414, radius: 0.212, strength: 0.442, elongation: 1.13, angle: -44.4)
        ], stops: Self.colors("#d2c8c5", "#cfb3c2", "#92236a", "#2b0013"), places: [0.444, 0.709], grain: 5)
        case .bloom: Setup(lights: [
            Light(-0.565, 1.272, radius: 0.124, strength: 1.666, elongation: 10.46, angle: -19.6),
            Light(0.091, 0.556, radius: 0.208, strength: 0.842, elongation: 3.88, angle: -12.9),
            Light(0.249, 0.864, radius: 0.146, strength: 0.426, elongation: 3.91, angle: 9.6),
            Light(0.974, 0.120, radius: 0.264, strength: 0.043, elongation: 1.84, angle: -79.0)
        ], stops: Self.colors("#cabbbe", "#a55684", "#6b1547", "#110007"), places: [0.120, 0.326], grain: 5, streaks: 0.08, streakAngle: -15)
        case .sand: Setup(lights: [
            Light(0.886, 0.292, radius: 1.015, strength: 0.821, elongation: 13.11, angle: 17.4),
            Light(-0.547, 0.901, radius: 0.173, strength: 0.532, elongation: 14.00, angle: -6.0),
            Light(0.156, 0.936, radius: 0.124, strength: 0.490, elongation: 10.15, angle: -4.1),
            Light(-0.206, 0.489, radius: 0.246, strength: 0.379, elongation: 4.42, angle: -8.1)
        ], stops: Self.colors("#c2a983", "#c1b59d", "#af8f62", "#8a5a36"), places: [0.838, 0.914], grain: 3, streaks: 0.15, streakAngle: -6)
        case .dusk: Setup(lights: [
            Light(0.045, 0.168, radius: 0.206, strength: 1.609, elongation: 2.23, angle: -32.7),
            Light(0.555, 0.923, radius: 0.158, strength: 0.700, elongation: 1.52, angle: -4.4),
            Light(0.719, 0.816, radius: 0.316, strength: 0.261, elongation: 1.59, angle: -47.6),
            Light(0.193, 1.143, radius: 0.344, strength: 0.212, elongation: 2.62, angle: -61.6)
        ], stops: Self.colors("#b3c3c6", "#8a97b1", "#59536a", "#320f1d"), places: [0.157, 0.353], grain: 4.5)
        case .rose: Setup(lights: [
            Light(-0.314, 0.931, radius: 0.170, strength: 3.000, elongation: 2.43, angle: -32.8),
            Light(0.713, 0.550, radius: 0.212, strength: 0.431, elongation: 2.48, angle: -61.8),
            Light(0.602, 0.336, radius: 0.239, strength: 0.235, elongation: 2.32, angle: 12.3),
            Light(0.598, 0.101, radius: 0.214, strength: 0.148, elongation: 2.39, angle: -43.7)
        ], stops: Self.colors("#cab4be", "#a35f87", "#65224a", "#000000"), places: [0.060, 0.256], grain: 7)
        case .indigo: Setup(lights: [
            Light(0.356, -0.800, radius: 0.344, strength: 1.005, elongation: 3.35, angle: 55.0),
            Light(-0.005, 0.293, radius: 0.490, strength: 0.931, elongation: 14.00, angle: -89.3),
            Light(0.989, 1.800, radius: 0.168, strength: 0.414, elongation: 10.06, angle: 56.5),
            Light(0.367, 0.586, radius: 0.156, strength: 0.171, elongation: 1.42, angle: 77.2)
        ], stops: Self.colors("#2d3163", "#494e90", "#6c81af", "#aac2c9"), places: [0.164, 0.424], grain: 7.5)
        case .mist: Setup(lights: [
            Light(0.885, 1.722, radius: 0.162, strength: 2.390, elongation: 6.40, angle: 51.9),
            Light(0.547, 1.637, radius: 0.129, strength: 1.002, elongation: 6.24, angle: 41.2),
            Light(0.428, 1.053, radius: 0.160, strength: 0.665, elongation: 4.62, angle: 46.8),
            Light(0.843, 0.446, radius: 0.347, strength: 0.077, elongation: 1.82, angle: 85.9)
        ], stops: Self.colors("#a8bcc2", "#616d95", "#3c3f68", "#2c1323"), places: [0.143, 0.344], grain: 3.5, streaks: 0.12, streakAngle: 50)
        }
    }

    /// A full-frame `lens` scene's picture when it names none: the film's, in its order.
    static func forShot(_ index: Int) -> LensPicture {
        let order: [LensPicture] = [.mist, .bloom, .sand, .dusk, .rose, .indigo]
        return order[index % order.count]
    }

    private static func colors(_ hexes: String...) -> [RGBAColor] {
        hexes.compactMap { RGBAColor(hex: $0) }
    }
}
