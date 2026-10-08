//
//  TimeMap.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// Maps between output time (the edited video, after cuts and speed changes) and source time (the
/// recording's), and edits cuts and speeds.
///
/// The only type that knows about cuts and speeds: everything else in a project is timed on the source,
/// so adding or moving a cut never invalidates an effect. Cuts and speeds are normalized here: clamped
/// to the recording, snapped to frame boundaries, sorted, and cuts merged.
nonisolated struct TimeMap: Equatable, Sendable {

    /// Source ranges left out, normalized.
    let cuts: [Range<Double>]

    /// The source ranges that are kept, in order.
    let keptRanges: [Range<Double>]

    /// Source ranges played at another speed, normalized: sorted, apart, none at 1×. Cut parts keep theirs.
    let speeds: [SpeedRange]

    /// The kept ranges divided where a speed starts or ends, each with its rate, in order.
    let pieces: [SpeedRange]

    let outputDuration: Double

    /// The output time at which each piece starts.
    private let outputStarts: [Double]

    /// Cuts are normalized as frame boundaries, so they're compared as integers.
    private let boundaries: FrameBoundaries

    /// - Parameters:
    ///   - cuts: Source ranges left out, in any order.
    ///   - speeds: Source ranges played at another speed, in any order; where two overlap, the earlier wins.
    ///   - sourceDuration: The recording's length in seconds.
    ///   - frameRate: The recording's frame rate, whose frames cuts snap to.
    init(cuts: [Range<Double>], speeds: [SpeedRange] = [], sourceDuration: Double, frameRate: Double) {
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

        var faster: [(range: Range<Int>, rate: Double)] = []
        for speed in speeds.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) where speed.rate > 0 && speed.rate != 1 {
            let lower = max(boundaries.nearest(speed.range.lowerBound), faster.last?.range.upperBound ?? 0)
            let upper = boundaries.nearest(speed.range.upperBound)
            if lower < upper {
                faster.append((lower..<upper, speed.rate))
            }
        }

        let time = { (range: Range<Int>) in boundaries.time(of: range.lowerBound)..<boundaries.time(of: range.upperBound) }
        self.cuts = merged.map(time)
        keptRanges = kept.map(time)
        self.speeds = faster.map { SpeedRange(range: time($0.range), rate: $0.rate) }
        pieces = Self.pieces(of: kept, at: faster).map { SpeedRange(range: time($0.range), rate: $0.rate) }
        var outputStarts: [Double] = []
        var output = 0.0
        for piece in pieces {
            outputStarts.append(output)
            output += (piece.range.upperBound - piece.range.lowerBound) / piece.rate
        }
        self.outputStarts = outputStarts
        outputDuration = output
    }

    /// `kept` divided where a speed in `faster` starts or ends, each part with its rate. Both are sorted and apart.
    private static func pieces(of kept: [Range<Int>], at faster: [(range: Range<Int>, rate: Double)]) -> [(range: Range<Int>, rate: Double)] {
        var pieces: [(range: Range<Int>, rate: Double)] = []
        var next = 0
        for range in kept {
            var start = range.lowerBound
            while start < range.upperBound {
                while next < faster.count, faster[next].range.upperBound <= start {
                    next += 1
                }
                let speed = next < faster.count ? faster[next] : nil
                if let speed, speed.range.lowerBound <= start {
                    let end = min(speed.range.upperBound, range.upperBound)
                    pieces.append((start..<end, speed.rate))
                    start = end
                } else {
                    let end = min(speed?.range.lowerBound ?? range.upperBound, range.upperBound)
                    pieces.append((start..<end, 1))
                    start = end
                }
            }
        }
        return pieces
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
        let index = pieces.partitioningIndex { $0.range.upperBound > time }
        guard index < pieces.count else { return outputDuration }
        return outputStarts[index] + max(time - pieces[index].range.lowerBound, 0) / pieces[index].rate
    }

    /// The output time showing source time `time`, or `nil` inside a cut.
    func outputTime(ifKept time: Double) -> Double? {
        let index = keptRanges.partitioningIndex { $0.upperBound > time }
        guard index < keptRanges.count, keptRanges[index].contains(time) else { return nil }
        return outputTime(atSource: time)
    }

    /// The source time shown at output time `time`, clamped to the output.
    func sourceTime(atOutput time: Double) -> Double {
        guard !pieces.isEmpty else { return 0 }
        let index = max(outputStarts.partitioningIndex { $0 > time } - 1, 0)
        let piece = pieces[index]
        return min(piece.range.lowerBound + max(time - outputStarts[index], 0) * piece.rate, piece.range.upperBound)
    }

    /// How fast source time `time` plays, whether or not it's cut.
    func rate(atSource time: Double) -> Double {
        let index = speeds.partitioningIndex { $0.range.upperBound > time }
        return index < speeds.count && speeds[index].range.contains(time) ? speeds[index].rate : 1
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

    /// The speeds with `range` played at `rate`, replacing whatever speed it had.
    func speeds(setting rate: Double, for range: Range<Double>) -> [SpeedRange] {
        let range = snapped(range.lowerBound)..<snapped(range.upperBound)
        let others = speeds.flatMap { speed in
            let (lower, upper) = (speed.range.lowerBound, speed.range.upperBound)
            return [lower..<max(min(upper, range.lowerBound), lower), min(max(lower, range.upperBound), upper)..<upper]
                .filter { !$0.isEmpty }
                .map { SpeedRange(range: $0, rate: speed.rate) }
        }
        return normalized(speeds: others + [SpeedRange(range: range, rate: rate)])
    }

    /// The speeds with `added` too, which mustn't overlap them.
    func speeds(adding added: [SpeedRange]) -> [SpeedRange] {
        normalized(speeds: speeds + added)
    }

    // MARK: Private

    private func normalized(_ cuts: [Range<Double>]) -> [Range<Double>] {
        TimeMap(cuts: cuts, sourceDuration: sourceDuration, frameRate: frameRate).cuts
    }

    private func normalized(speeds: [SpeedRange]) -> [SpeedRange] {
        TimeMap(cuts: [], speeds: speeds, sourceDuration: sourceDuration, frameRate: frameRate).speeds
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
