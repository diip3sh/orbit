//
//  TimeMap.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// Maps between output time (the edited video, after cuts) and source time (the recording's), and
/// edits cuts.
///
/// The only type that knows about cuts: everything else in a project is timed on the source, so
/// adding or moving a cut never invalidates an effect. Cuts are normalized here: clamped to the
/// recording, snapped to frame boundaries, sorted and merged.
nonisolated struct TimeMap: Equatable, Sendable {

    /// Source ranges left out, normalized.
    let cuts: [Range<Double>]

    /// The source ranges that are kept, in order.
    let keptRanges: [Range<Double>]

    let outputDuration: Double

    /// The output time at which each kept range starts.
    private let outputStarts: [Double]

    /// Cuts are normalized as frame boundaries, so they're compared as integers.
    private let boundaries: FrameBoundaries

    /// - Parameters:
    ///   - cuts: Source ranges left out, in any order.
    ///   - sourceDuration: The recording's length in seconds.
    ///   - frameRate: The recording's frame rate, whose frames cuts snap to.
    init(cuts: [Range<Double>], sourceDuration: Double, frameRate: Double) {
        let boundaries = FrameBoundaries(
            frameRate: frameRate, sourceDuration: sourceDuration, last: FrameGrid(frameRate: frameRate, duration: sourceDuration).frameCount
        )
        self.boundaries = boundaries

        var merged: [Range<Int>] = []
        let snapped = cuts.map { boundaries.nearest($0.lowerBound)..<boundaries.nearest($0.upperBound) }
        for cut in snapped.sorted(by: { $0.lowerBound < $1.lowerBound }) where !cut.isEmpty {
            if let last = merged.last, cut.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, cut.upperBound)
            } else {
                merged.append(cut)
            }
        }

        var kept: [Range<Int>] = []
        var start = 0
        for cut in merged {
            if cut.lowerBound > start {
                kept.append(start..<cut.lowerBound)
            }
            start = cut.upperBound
        }
        if boundaries.last > start {
            kept.append(start..<boundaries.last)
        }

        self.cuts = merged.map { boundaries.time(of: $0.lowerBound)..<boundaries.time(of: $0.upperBound) }
        keptRanges = kept.map { boundaries.time(of: $0.lowerBound)..<boundaries.time(of: $0.upperBound) }
        var outputStarts: [Double] = []
        var output = 0.0
        for range in keptRanges {
            outputStarts.append(output)
            output += range.upperBound - range.lowerBound
        }
        self.outputStarts = outputStarts
        outputDuration = output
    }

    var sourceDuration: Double {
        boundaries.sourceDuration
    }

    var frameRate: Double {
        boundaries.frameRate
    }

    /// The output time showing source time `time`. Inside a cut, it's where the content after the
    /// cut starts, or the end of the output.
    func outputTime(atSource time: Double) -> Double {
        let index = keptRanges.partitioningIndex { $0.upperBound > time }
        guard index < keptRanges.count else { return outputDuration }
        return outputStarts[index] + max(time - keptRanges[index].lowerBound, 0)
    }

    /// The source time shown at output time `time`, clamped to the output.
    func sourceTime(atOutput time: Double) -> Double {
        guard !keptRanges.isEmpty else { return 0 }
        let index = max(outputStarts.partitioningIndex { $0 > time } - 1, 0)
        let range = keptRanges[index]
        return min(range.lowerBound + max(time - outputStarts[index], 0), range.upperBound)
    }

    /// The source time of the frame boundary nearest `time`.
    func snapped(_ time: Double) -> Double {
        boundaries.time(of: boundaries.nearest(time))
    }
}

// MARK: - Editing

nonisolated extension TimeMap {

    /// The cuts with `range` cut too.
    func cuts(adding range: Range<Double>) -> [Range<Double>] {
        normalized(cuts + [range])
    }

    /// The cuts with `range` restored.
    func cuts(removing range: Range<Double>) -> [Range<Double>] {
        normalized(cuts.flatMap { cut in
            [cut.lowerBound..<max(min(cut.upperBound, range.lowerBound), cut.lowerBound),
             min(max(cut.lowerBound, range.upperBound), cut.upperBound)..<cut.upperBound]
        })
    }

    /// The cuts with kept range `index` starting at `time` instead: later cuts its head, earlier
    /// restores what was cut before it, up to the previous kept range. At least one frame stays.
    func cuts(movingStartOf index: Int, to time: Double) -> [Range<Double>] {
        let range = keptRanges[index]
        let earliest = index > 0 ? keptRanges[index - 1].upperBound : 0
        let latest = max(range.upperBound - 1 / frameRate, range.lowerBound)
        let start = min(max(time, earliest), latest)
        return start < range.lowerBound ? cuts(removing: start..<range.lowerBound) : cuts(adding: range.lowerBound..<start)
    }

    /// The cuts with kept range `index` ending at `time` instead: earlier cuts its tail, later
    /// restores what was cut after it, up to the next kept range. At least one frame stays.
    func cuts(movingEndOf index: Int, to time: Double) -> [Range<Double>] {
        let range = keptRanges[index]
        let latest = index + 1 < keptRanges.count ? keptRanges[index + 1].lowerBound : sourceDuration
        let earliest = min(range.lowerBound + 1 / frameRate, range.upperBound)
        let end = max(min(time, latest), earliest)
        return end > range.upperBound ? cuts(removing: range.upperBound..<end) : cuts(adding: end..<range.upperBound)
    }

    /// The kept ranges divided at `splits`, source times that are snapped to frames. Splits inside
    /// a cut or on a kept range's edge divide nothing.
    func segments(splitAt splits: [Double]) -> [Range<Double>] {
        let splits = Set(splits.map(boundaries.nearest)).sorted()
        return keptRanges.flatMap { range in
            let lower = boundaries.nearest(range.lowerBound)
            let upper = boundaries.nearest(range.upperBound)
            let inside = splits.filter { $0 > lower && $0 < upper }
            return zip([lower] + inside, inside + [upper]).map { boundaries.time(of: $0)..<boundaries.time(of: $1) }
        }
    }

    // MARK: Private

    private func normalized(_ cuts: [Range<Double>]) -> [Range<Double>] {
        TimeMap(cuts: cuts, sourceDuration: sourceDuration, frameRate: frameRate).cuts
    }

    /// Boundary `n` is where frame `n` starts, and the last is the source's end, wherever that falls.
    private struct FrameBoundaries: Equatable {
        let frameRate: Double
        let sourceDuration: Double
        let last: Int

        func nearest(_ time: Double) -> Int {
            Int(min(max(0, (time * frameRate).rounded()), Double(last)))
        }

        func time(of boundary: Int) -> Double {
            boundary == last ? sourceDuration : Double(boundary) / frameRate
        }
    }
}
