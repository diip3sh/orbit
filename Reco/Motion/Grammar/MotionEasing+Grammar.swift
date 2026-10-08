//
//  MotionEasing+Grammar.swift
//  Reco
//

import Foundation

/// The grammar's easings, the only ones its moves use (spec 0011, *Craft defaults* and *Measured
/// references*). Only motion design's (spec 0014) overshoot: Raycast's films never do, its reference always does.
nonisolated extension MotionEasing {

    /// Out-cubic: what enters.
    static let enter = MotionEasing.cubicBezier(0.33, 1, 0.68, 1)

    /// Out-expo: what lands fast, like a zoom through a cut.
    static let enterFast = MotionEasing.cubicBezier(0.16, 1, 0.3, 1)

    /// Out-quart: rows of a cascade, as Raycast's list (30–33 frames at 30 fps).
    static let cascade = MotionEasing.cubicBezier(0.25, 1, 0.5, 1)

    /// In-cubic: what leaves, shorter than it entered.
    static let exit = MotionEasing.cubicBezier(0.32, 0, 0.67, 0)

    /// Moves across the screen as the reference films' UI does: peak speed at 43% of the move, 65% of
    /// the way by mid-time (17 moves measured).
    static let move = MotionEasing.cubicBezier(0.5, 0, 0.2, 1)

    /// A whip: slow off, a streak, slow in; the approved film's keyframes to its code block.
    static let whip = MotionEasing.cubicBezier(0.7, 0, 0.15, 1)

    /// Framer's pull-back: from full speed on a cut, half done at 0.65 s, 90% at 2.55 s.
    static let longSettle = MotionEasing.settle(timeConstant: 0.9)

    /// A change of state in motion design: the Spotify Jam film's pill growing out of a dot, fitted to its widths
    /// frame by frame over 0.43 s (spec 0014).
    static let morph = MotionEasing.cubicBezier(0.36, 0.2, 0.12, 1)

    /// Past its end by 10% and back: letters springing in, pops and hovers in motion design. CSS's out-back.
    static let overshoot = MotionEasing.cubicBezier(0.34, 1.56, 0.64, 1)

    /// In-out cubic: a list scrolled fast, slow off and slow in, blurred in its middle.
    static let scroll = MotionEasing.cubicBezier(0.65, 0, 0.35, 1)
}
