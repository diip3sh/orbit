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
        /// Letters spring up into place one after another, overshooting (spec 0014): ``letterPose(_:)``.
        case letter
        /// Characters appear whole behind a caret in the accent, the newest in the accent too (spec 0014).
        case kinetic
    }

    let style: Style
    let start: Double
    let stagger: Double
    let partDuration: Double

    /// How far part `index` is shown at `time`, eased: 0 to 1. A letter's way in is ``letterPose(_:)``.
    func progress(ofPart index: Int, at time: Double) -> Double {
        let fraction = fraction(ofPart: index, at: time)
        guard partDuration > 0 else { return fraction }
        return MotionEasing.enter.progress(fraction, duration: partDuration)
    }

    /// Where a letter is `fraction` of its way in. Measured on the Spotify Jam film's "Start a Jam" (30 fps, the pill's own
    /// lift taken out): a letter comes up from about 0.7 of its line below at a third of its size, is at 1.35× a quarter line
    /// above its place a quarter of the way in (0.1 s), and eases back down from there with no second bounce.
    static func letterPose(_ fraction: Double) -> LetterPose {
        let opacity = min(fraction / letterFadeIn, 1)
        guard fraction < letterPeak else {
            // In-out cubic, as measured: its height fell slowly from the peak, fastest half way, slowly onto its size
            let settle = MotionEasing.scroll.progress((fraction - letterPeak) / (1 - letterPeak), duration: 1)
            return LetterPose(below: letterAbove * (1 - settle), scale: letterGrowth + (1 - letterGrowth) * settle, opacity: opacity)
        }
        let thrown = MotionEasing.enter.progress(fraction / letterPeak, duration: 1)
        return LetterPose(below: letterBelow + (letterAbove - letterBelow) * thrown, scale: letterFrom + (letterGrowth - letterFrom) * thrown, opacity: opacity)
    }

    /// A letter on its way in: lines below its place (negative above), its scale about its middle, its opacity.
    nonisolated struct LetterPose: Equatable, Sendable {
        let below: Double
        let scale: Double
        let opacity: Double
    }

    /// A letter's start (lines below, scale), its peak (lines below, negative above; scale) and when it peaks, as a share of
    /// its time; it's opaque after ``letterFadeIn`` of it.
    static let letterBelow = 0.7
    static let letterFrom = 0.3
    static let letterAbove = -0.25
    static let letterGrowth = 1.35
    static let letterPeak = 0.25
    static let letterFadeIn = 0.15

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
