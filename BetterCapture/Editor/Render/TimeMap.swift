//
//  TimeMap.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// Maps between output time (the edited video, after cuts) and source time (the recording's).
///
/// The only type that knows about cuts: everything else in a project is timed on the source, so
/// adding or moving a cut never invalidates an effect.
nonisolated struct TimeMap: Equatable, Sendable {

    /// The source ranges that are kept, in order.
    let keptRanges: [Range<Double>]

    let outputDuration: Double

    /// - Parameters:
    ///   - cuts: Source ranges left out, sorted and non-overlapping.
    ///   - sourceDuration: The recording's length in seconds.
    init(cuts: [Range<Double>], sourceDuration: Double) {
        var keptRanges: [Range<Double>] = []
        var start = 0.0
        for cut in cuts {
            let end = min(cut.lowerBound, sourceDuration)
            if end > start {
                keptRanges.append(start..<end)
            }
            start = max(start, cut.upperBound)
        }
        if sourceDuration > start {
            keptRanges.append(start..<sourceDuration)
        }

        self.keptRanges = keptRanges
        outputDuration = keptRanges.reduce(0) { $0 + $1.upperBound - $1.lowerBound }
    }

    /// The output time showing source time `time`, or `nil` when it was cut.
    func outputTime(atSource time: Double) -> Double? {
        var output = 0.0
        for range in keptRanges {
            if range.contains(time) {
                return output + time - range.lowerBound
            }
            output += range.upperBound - range.lowerBound
        }
        return nil
    }

    /// The source time shown at output time `time`, clamped to the output.
    func sourceTime(atOutput time: Double) -> Double {
        var remaining = max(time, 0)
        for range in keptRanges {
            let length = range.upperBound - range.lowerBound
            if remaining < length {
                return range.lowerBound + remaining
            }
            remaining -= length
        }
        return keptRanges.last?.upperBound ?? 0
    }
}
