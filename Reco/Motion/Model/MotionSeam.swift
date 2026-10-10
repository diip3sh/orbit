//
//  MotionSeam.swift
//  Reco
//

import Foundation

/// How a scene begins after the one before (``SeamExpansion``). Reference films cut 68% of the time,
/// move through 25% and fade 5% (Remocn, 449 intervals).
nonisolated enum MotionSeam: String, Codable, CaseIterable, Sendable {
    case cut

    /// A cut that carries the camera's speed and direction into the next scene, then settles.
    case cutOnMotion

    /// The camera rushes in 0.2 s and lands from a pulled-back view in 0.5 s, blurred across the cut.
    case zoomThrough

    /// The camera streaks sideways out of the scene and into the next from the same side: one whip
    /// across the cut, its motion blur hiding it (Raycast's grid to its next state).
    case whip

    /// The frame blurs out and the next blurs in.
    case blurCut

    /// The next scene slides in and pushes this one out.
    case push

    /// A cross-fade: rare in the references.
    case fade

    /// The next scene rises from below on a card with rounded corners while this one sinks back, dims and blurs: a
    /// sheet coming up over a page.
    case stack

    /// A rounded rectangle grows out of what the scene before clicked last (else its middle) to the whole frame, the
    /// next scene inside it, while this one dives towards it: an app opening from its icon.
    case expand

    /// The camera tilts and dives into what the scene before clicked last (else its middle) until it fills the frame, the
    /// next scene seen through it coming up from further back: flying through a glass prompt into what it made (Vantae).
    case dive

    /// The frame dissolves into the next by its own light, its darks first, in grain, a front of the brand's colour where
    /// it goes: an image melting into the ground (Vantae's room into its blue, its ground into a meadow).
    case melt

    /// A front of grainy light in the brand's colour crosses the frame out of the light's shape, the next
    /// scene behind it: the light looks' seam (``MotionField/Family/light``).
    case glow

    /// The frame turns to the brand's ordered dots from its edges in, its UI drawn in them, flips to the
    /// next scene's and resolves into it: the dither looks' seam (Vercel Ship's dither eating its footage).
    case dither

    /// A ring of smoke opens from the middle past the frame's corners, the next scene inside it (Opera's
    /// ring portal): into a closing or a logo, in any look but satin's.
    case ring
}

nonisolated extension MotionSeam {

    /// The field family whose language the seam is drawn in, if it has one.
    var family: MotionField.Family? {
        switch self {
        case .glow: .light
        case .dither: .dither
        case .ring: .smoke
        default: nil
        }
    }
}
