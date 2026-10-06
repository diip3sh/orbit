//
//  MotionEasing+Grammar.swift
//  Reco
//

import Foundation

/// The grammar's easings, the only ones its moves use (spec 0011, *Craft defaults* and *Measured
/// references*). None overshoots.
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

    /// Framer's pull-back: from full speed on a cut, half done at 0.65 s, 90% at 2.55 s.
    static let longSettle = MotionEasing.settle(timeConstant: 0.9)
}
