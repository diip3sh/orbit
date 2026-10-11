//
//  LensPicture.swift
//  Reco
//

import Foundation

/// The editorial film's pictures (spec 0017, ``MotionField/lens``): colour photographs far out of focus, grainy, as ElevenLabs'
/// launch film shows them full frame and in its cards (`~/Movies/Reco/references/elevenlabs-launch.mp4`), named for what
/// they look like. How each is drawn is ``Setup``.
nonisolated enum LensPicture: String, Codable, CaseIterable, Sendable {
    /// Teal sky streaked white (the opening's square, 3.0 s).
    case sky
    /// Violet light streaking in from a corner over pale blue (2.5 s).
    case violet
    /// Pale sand under a blue haze, streaked (3.6 s).
    case dune
    /// A magenta petal over pale pink, its heart near black (4.0 s).
    case petal
    /// Crimson sweeping across mauve (the prompt's ground, 36.4 s).
    case bloom
    /// Ochre dunes in long streaks (54.9 s).
    case sand
    /// Pale blue, a plum shadow in a corner and one below (55.6 s).
    case dusk
    /// Mauve with a deep plum bloom (56.2 s).
    case rose
    /// Pale blue under a deep indigo cloud (57.0 s).
    case indigo
    /// Slate blue streaked deep violet from below (the question's ground, 9.4 s).
    case mist

    /// Its mean colour, measured on the film's frame it was fitted to (blurred, the type over it left out): what type over it is
    /// read against. White type reads on all but dune (1.7:1) and sand (2.6:1), where the film's own white type was faint.
    var mean: RGBAColor {
        let hex = switch self {
        case .sky: "#7092a8"
        case .violet: "#808aa5"
        case .dune: "#d2c4a8"
        case .petal: "#ae7a97"
        case .bloom: "#96667f"
        case .sand: "#b59e7d"
        case .dusk: "#868d9e"
        case .rose: "#96617f"
        case .indigo: "#7283a9"
        case .mist: "#79869d"
        }
        return RGBAColor(hex: hex) ?? RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
    }
}
