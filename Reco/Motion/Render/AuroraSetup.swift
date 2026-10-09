//
//  AuroraSetup.swift
//  Reco
//

import CoreGraphics

/// Where the light falls in one shot over the aurora field (spec 0015): Lovable's launch film keeps most of its frame
/// black and lets soft lights in from its edges in its gradient, blue where they're faint, warm only at a strong
/// light's middle; the light is in a new place at every cut and drifts within a shot. A dark ellipse lit round its
/// edge drew a ring round every frame; the film's light comes from one or two places.
nonisolated struct AuroraSetup: Equatable, Sendable {

    /// A soft light: its middle in fractions of the frame from its top-left (lights sit at or past its edges), its radius
    /// across in frame heights, how much longer it runs along its `angle` (degrees, clockwise from across), and how far
    /// along the ramp it reaches at its middle (``brandSpan``'s end is the gradient's last colour).
    nonisolated struct Light: Equatable, Sendable {
        var center: CGPoint
        var radius: Double
        var strength: Double
        var elongation: Double
        var angle: Double

        init(_ across: Double, _ down: Double, radius: Double, strength: Double, elongation: Double = 1, angle: Double = 0) {
            center = CGPoint(x: across, y: down)
            self.radius = radius
            self.strength = strength
            self.elongation = elongation
            self.angle = angle
        }
    }

    /// At most ``mostLights``, summed.
    var lights: [Light]

    static let mostLights = 5

    /// The shots' setups in turn, fitted to the film's frames at 0.5, 42.8, 19.8, 24.5, 13 and 3.6 s (2560×1440) in OKLab,
    /// its UI masked out: a warm sweep down from the top left, light along the top, a sweep and a far corner, a corner
    /// alone, a dark frame lit faintly from above, light all round. Round lights drew rings round every frame, their
    /// colour bands circles; the film's light runs in long diagonal sweeps along its corners and edges, so each light is
    /// two to twelve times longer than it is wide, its middle at or past the frame's edge. The mean colour error fell from
    /// 0.07–0.23 to 0.011–0.034; black and lit shares are within 4 points of the film's on every frame.
    static let shots = [
        AuroraSetup(lights: [
            Light(-0.018, 0.094, radius: 0.285, strength: 0.712, elongation: 2.07, angle: -55.4),
            Light(1.176, 0.576, radius: 0.347, strength: 0.624, elongation: 3.55, angle: -41.2),
            Light(0.282, 0.001, radius: 0.302, strength: 0.622, elongation: 1.42, angle: -33.6)
        ]),
        AuroraSetup(lights: [
            Light(0.325, -0.067, radius: 0.466, strength: 0.526, elongation: 3.55, angle: -3.1),
            Light(1.008, 0.963, radius: 0.515, strength: 0.435, elongation: 2.02, angle: -41.4),
            Light(0.240, 1.072, radius: 0.440, strength: 0.161, elongation: 2.59, angle: 16.1)
        ]),
        AuroraSetup(lights: [
            Light(-0.004, 0.016, radius: 0.298, strength: 0.670, elongation: 1.79, angle: -50.9),
            Light(1.010, 0.804, radius: 0.307, strength: 0.587, elongation: 3.49, angle: -47.7),
            Light(0.267, 0.001, radius: 0.242, strength: 0.545, elongation: 1.96, angle: -29.2)
        ]),
        AuroraSetup(lights: [
            Light(1.281, 1.105, radius: 0.2, strength: 0.902, elongation: 3.65, angle: -10),
            Light(1, 0.86, radius: 0.2, strength: 0.253, elongation: 2.42, angle: -22.6),
            Light(0.041, -0.029, radius: 0.2, strength: 0.247, elongation: 2.15, angle: -33.4)
        ]),
        AuroraSetup(lights: [
            Light(1.328, -0.316, radius: 0.295, strength: 0.725, elongation: 6.62, angle: -3.2),
            Light(1.459, 0.176, radius: 0.2, strength: 0.253, elongation: 12, angle: 0.7),
            Light(0, 0.931, radius: 0.231, strength: 0.244, elongation: 3.61, angle: 25.2)
        ]),
        AuroraSetup(lights: [
            Light(0.595, -2, radius: 1.004, strength: 1.271, elongation: 2.58, angle: 65.3),
            Light(0.09, -2, radius: 0.785, strength: 0.812, elongation: 4.05, angle: -80.1),
            Light(0.979, 1.047, radius: 0.391, strength: 0.419, elongation: 3.31, angle: -20.6),
            Light(0.081, 1.083, radius: 0.365, strength: 0.304, elongation: 1.88, angle: 24.1)
        ])
    ]

    /// The last shot's: the light ringing a dark middle, warmest in the bottom right (the film's end words, 45.3 s).
    static let ending = AuroraSetup(lights: [
        Light(0.887, -1.52, radius: 0.64, strength: 0.644, elongation: 4.62, angle: 80.3),
        Light(0.048, 2.105, radius: 0.555, strength: 0.457, elongation: 9.7, angle: 82.8),
        Light(0.945, 1.066, radius: 0.438, strength: 0.399, elongation: 2.66, angle: -10.1),
        Light(0.286, -0.05, radius: 0.442, strength: 0.391, elongation: 2.37, angle: 0.5)
    ])

    static func forShot(_ index: Int, isLast: Bool) -> AuroraSetup {
        isLast ? ending : shots[index % shots.count]
    }

    // MARK: - The light's colours

    /// Where the dark's stops lie along the ramp (the lights' summed reach), and their OKLCH lightness and chroma (as a
    /// share of the gradient's first colour's, in its hue): black, then navy into the brand's first colour, as the film's
    /// #020309, #0b1330, #1b275d, #2f4298 and #4f68ee led into its blue #5b6ff8. Their places were fitted with the lights:
    /// black reaches further and the navy is narrower than first measured.
    static let core = [
        Stop(0, lightness: 0, chromaShare: 0), Stop(0.14, lightness: 0.1, chromaShare: 0.1), Stop(0.21, lightness: 0.2, chromaShare: 0.29),
        Stop(0.3, lightness: 0.3, chromaShare: 0.48), Stop(0.4, lightness: 0.42, chromaShare: 0.7), Stop(0.52, lightness: 0.575, chromaShare: 1)
    ]

    nonisolated struct Stop: Sendable {
        let position: Double
        let lightness: Double
        let chromaShare: Double

        init(_ position: Double, lightness: Double, chromaShare: Double) {
            (self.position, self.lightness, self.chromaShare) = (position, lightness, chromaShare)
        }
    }

    /// The brand's gradient lies past the core, its first colour at the near end: the film's blue, violet, pink, red and
    /// orange, only at a strong light's middle. Fitted with the lights, so a strong corner reaches the warm end as the
    /// film's do.
    static let brandSpan = 0.55...0.92

    /// How far the ramp the kernel reads runs; past its last stop it holds that colour.
    static let rampEnd = 1.2

    /// The video's first shot: its light comes in from nothing over this long, its lights growing from this share of
    /// their radius (the film's corner light sweeps in over its first half second).
    static let swell = (from: 0.7, length: 0.6)

    /// The light goes out before the video ends: from this long before the end, over a second, leaving the logo on
    /// black (the film's faded from 46.8 to 47.8 s, the logo held to 48.8).
    static let fade = (before: 2.0, length: 1.0)

    /// How much of the light shows `time` seconds into a video `length` long.
    static func light(at time: Double, length: Double) -> Double {
        let gone = (time - (length - fade.before)) / fade.length
        return 1 - MotionEasing.scroll.progress(min(max(gone, 0), 1), duration: 1)
    }
}
