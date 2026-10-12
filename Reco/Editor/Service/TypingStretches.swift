//
//  TypingStretches.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import Foundation

/// Finds where the user was typing, to play it faster. A pure function of the key presses.
nonisolated enum TypingStretches {

    /// Presses further apart than this, in seconds, start a new stretch.
    static let maximumGap = 1.0

    /// Stretches shorter than this, from the first press to the last, are left at 1×.
    static let minimumDuration = 3.0

    /// A press with one of these is a shortcut: it does something worth seeing, so it ends a stretch.
    private static let shortcutModifiers: Set = ["control", "option", "command"]

    /// The stretches of typing, each with the speed it plays at. Auto-repeats neither extend nor end one.
    /// - Parameter keys: Sorted by time.
    static func speedUps(for keys: [InputTelemetry.Key]) -> [SpeedRange] {
        var stretches: [SpeedRange] = []
        var current: Range<Double>?
        func close() {
            if let range = current, range.upperBound - range.lowerBound >= minimumDuration {
                stretches.append(SpeedRange(range: range, rate: rate(forDuration: range.upperBound - range.lowerBound)))
            }
            current = nil
        }
        for key in keys where !key.isRepeat {
            if !shortcutModifiers.isDisjoint(with: key.modifiers) {
                close()
            } else if let range = current, key.time - range.upperBound < maximumGap {
                current = range.lowerBound..<key.time
            } else {
                close()
                current = key.time..<key.time
            }
        }
        close()
        return stretches
    }

    /// Longer stretches play faster, so none drags on: 2× under 6 s, 3× under 12 s, 4× beyond.
    static func rate(forDuration duration: Double) -> Double {
        switch duration {
        case ..<6: 2
        case ..<12: 3
        default: 4
        }
    }
}
