//
//  BeatGrid.swift
//  Reco
//

import Foundation

/// A beat score's grid (spec 0015): one tempo throughout, its beats where the film cuts. Lovable's cuts land on
/// its track's beats within 40 ms; a film's cuts are on its frames, so the grid is fitted to them instead.
nonisolated struct BeatGrid: Equatable, Sendable {

    /// Seconds a beat.
    let beat: Double

    /// A beat's time in [0, beat): the first one.
    let phase: Double

    var bar: Double {
        4 * beat
    }

    var tempo: Double {
        60 / beat
    }

    /// The beat nearest `time`, in seconds; never before the first.
    func nearest(_ time: Double) -> Double {
        phase + max(((time - phase) / beat).rounded(), 0) * beat
    }

    /// The sixteenth nearest `time`, in seconds.
    func nearestSixteenth(_ time: Double) -> Double {
        let sixteenth = beat / 4
        return phase + ((time - phase) / sixteenth).rounded() * sixteenth
    }

    /// How many beats `time` is after the first beat, rounded.
    func beats(to time: Double) -> Int {
        Int(((time - phase) / beat).rounded())
    }

    /// The grid near `tempo` (within ``SoundRules/tempoReach``) whose beats the most of `cuts` land on (within
    /// ``SoundRules/beatTolerance``); between equals, the one they land on closest for a tempo nearest the style's
    /// (``Score/driftCost``), then the earliest first beat.
    static func fitted(to cuts: [Double], tempo: Double) -> BeatGrid {
        guard !cuts.isEmpty else { return BeatGrid(beat: 60 / tempo, phase: 0) }
        let tempos = stride(from: tempo * (1 - SoundRules.tempoReach), through: tempo * (1 + SoundRules.tempoReach), by: SoundRules.tempoStep)
        var best: (grid: BeatGrid, score: Score)?
        for candidate in tempos {
            let beat = 60 / candidate
            for phase in stride(from: 0, to: beat, by: SoundRules.phaseStep) {
                var score = Score(landed: 0, offset: 0, drift: abs(candidate - tempo), phase: phase)
                for cut in cuts {
                    let off = abs(remainder(cut - phase, beat))
                    if off <= SoundRules.beatTolerance {
                        score.landed += 1
                        score.offset += off
                    }
                }
                if best.map({ score < $0.score }) ?? true {
                    best = (BeatGrid(beat: beat, phase: phase), score)
                }
            }
        }
        return best?.grid ?? BeatGrid(beat: 60 / tempo, phase: 0)
    }

    /// How well a grid fits: lower is better.
    private struct Score: Comparable {
        var landed: Int
        var offset: Double
        let drift: Double
        let phase: Double

        /// A BPM away from the style's costs as much as cuts 2 ms further off their beats: with three cuts, a grid at
        /// 174.9 BPM landed them closer than 170 did, and the groove ran fast.
        static let driftCost = 0.002

        static func < (lhs: Score, rhs: Score) -> Bool {
            if lhs.landed != rhs.landed { return lhs.landed > rhs.landed }
            let cost = { (score: Score) in score.offset / Double(max(score.landed, 1)) + driftCost * score.drift }
            if abs(cost(lhs) - cost(rhs)) > 1e-9 { return cost(lhs) < cost(rhs) }
            return lhs.phase < rhs.phase
        }
    }
}
