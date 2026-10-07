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
    }

    let style: Style
    let start: Double
    let stagger: Double
    let partDuration: Double

    /// How far part `index` is shown at `time`, 0 to 1, eased.
    func progress(ofPart index: Int, at time: Double) -> Double {
        let elapsed = time - start - Double(index) * stagger
        guard partDuration > 0 else { return elapsed >= 0 ? 1 : 0 }
        return MotionEasing.enter.progress(elapsed / partDuration, duration: partDuration)
    }

    /// When the last of `parts` is shown in full.
    func end(parts: Int) -> Double {
        start + Double(max(parts - 1, 0)) * stagger + partDuration
    }
}
