//
//  TextReveal.swift
//  Reco
//

import Foundation

/// A text layer shown part by part: characters typed or wiped in, words fading up, lines rising out
/// of their mask.
/// Each part takes `partDuration` from `start + index × stagger`.
nonisolated struct TextReveal: Equatable, Sendable {

    nonisolated enum Style: Equatable, Sendable {
        /// Characters appear whole, one after another.
        case type
        /// Characters sharpen and fade in left to right.
        case wipe
        /// Lines rise into place, cut off below their own box.
        case rise
        /// Words fade up into place, one after another.
        case word
        /// Letters spring up into place one after another, sharpening and overshooting (spec 0014).
        case letter
        /// Characters appear whole behind a caret in the accent, the newest in the accent too (spec 0014).
        case kinetic
    }

    let style: Style
    let start: Double
    let stagger: Double
    let partDuration: Double

    /// How far part `index` is shown at `time`, eased: 0 to 1, past 1 for a while as a letter overshoots.
    func progress(ofPart index: Int, at time: Double) -> Double {
        let fraction = fraction(ofPart: index, at: time)
        guard partDuration > 0 else { return fraction }
        return (style == .letter ? MotionEasing.overshoot : .enter).progress(fraction, duration: partDuration)
    }

    /// How much of part `index`'s time has passed at `time`, 0 to 1, not eased: 1 once it's at rest.
    func fraction(ofPart index: Int, at time: Double) -> Double {
        let elapsed = time - start - Double(index) * stagger
        guard partDuration > 0 else { return elapsed >= 0 ? 1 : 0 }
        return min(max(elapsed / partDuration, 0), 1)
    }

    /// When part `index` starts.
    func start(ofPart index: Int) -> Double {
        start + Double(index) * stagger
    }

    /// When the last of `parts` is shown in full.
    func end(parts: Int) -> Double {
        start + Double(max(parts - 1, 0)) * stagger + partDuration
    }
}
