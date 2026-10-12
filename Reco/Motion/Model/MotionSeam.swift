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

    /// The scene turns away round where the camera looks and the next turns in from the other side, blurred as it goes: a
    /// whip in depth (spec 0020).
    case swing

    /// The next scene's layers arrive over this one's as its layers leave, one after another; a layer with the same id in both
    /// travels from its place in this scene to its place in the next, changing shape and colour on the way (spec 0020).
    case flow

    /// A cross-fade: rare in the references.
    case fade

    /// The next scene rises from below on a card with rounded corners while this one sinks back, dims and blurs: a
    /// sheet coming up over a page.
    case stack

    /// A rounded rectangle grows out of what the scene before clicked last (else its middle) to the whole frame, the
    /// next scene inside it, while this one dives towards it: an app opening from its icon.
    case expand

    /// The next scene sweeps in from the right behind a very soft edge, most of the frame wide, speeding up: the editorial
    /// film's picture coming in over its wordmark (spec 0017).
    case wipe

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

    // Graphic transitions in the brand's colours, any look (spec 0019): the devices of After Effects launch films.

    /// A disc of the brand's colour opens out of what was clicked (else the middle), the next scene's disc following inside it.
    case iris

    /// Two bars in the brand's colours, then the next scene, sweep across one after another, their edges slanted.
    case bars

    /// The next scene slides in as horizontal strips from alternate sides, the middle ones first.
    case slats

    /// The next scene opens as a grid of tiles, each from a dot of the brand's colour to a square, in a wave.
    case tiles

    /// The frame splits down the middle and its halves slide apart, the next scene coming up behind them.
    case split

    /// The frame spins away blurred along its turn and the next spins in.
    case spin

    /// The frame tears into shifted bands with its colours apart, blocks of the next showing through, for a moment.
    case glitch

    /// The frame breaks into blocks that grow, then the next resolves out of them.
    case pixelate

    /// Blobs of the brand's colours swell out of a corner (or what was clicked) with wobbling edges, the next scene inside.
    case liquid

    /// The frame turns over as a card, the next scene on its back.
    case flip

    /// The frame turns away on a cube, the next scene on its next face.
    case cube

    /// A flash of the brand's colour on the cut, the next scene settling out of it.
    case flash

    /// The frame stretches away along one axis, blurred, and the next snaps back from stretched.
    case stretch
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

    /// The graphic transitions any look may use, drawn in the brand's colours (spec 0019).
    static let graphic: Set<MotionSeam> = [.iris, .bars, .slats, .tiles, .split, .spin, .glitch, .pixelate, .liquid, .flip, .cube, .flash, .stretch]
}
