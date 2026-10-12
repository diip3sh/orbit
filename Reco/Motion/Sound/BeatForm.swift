//
//  BeatForm.swift
//  Reco
//

import Foundation

/// Where a beat score's parts go (spec 0015), read from the film's scenes. Lovable's track has an intro without
/// drums until the story starts (8.5 s), a break under the big "Ready to build it?" (33.5–37 s), and drums out under
/// the end words (43.6 s on), landing on a last hit; the Spotify Jam's plays from the first frame to the last,
/// stopping for a beat once. Where drums carry on after an edge it's on a beat; the outro and the last hit are on
/// their cuts.
nonisolated struct BeatForm: Equatable, Sendable {

    /// A scene as the form reads it: when it shows, and whether it's words alone (text, and at most a logo).
    nonisolated struct Shot: Equatable, Sendable {
        let start: Double
        let end: Double
        let isWords: Bool
    }

    /// Where the drums come in: the first beat when there's no intro.
    var drop: Double

    /// Where the drums stop for a while: a break (kick and bass out, the hats on) or a dip (all out for a beat).
    var breaks: [Range<Double>] = []

    /// Drums out from here to the end; `nil` when they play to the last frame.
    var outro: Double?

    /// The last hit, landing home: the logo's cut.
    var lastHit: Double?

    let end: Double

    /// The drums' stretches: from the drop to the outro or the end, between the breaks.
    var segments: [Range<Double>] {
        let stop = outro ?? end
        var edges = [(drop, stop)]
        for gap in breaks.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            guard let last = edges.popLast() else { break }
            edges += [(last.0, min(gap.lowerBound, last.1)), (max(gap.upperBound, last.0), last.1)]
        }
        return edges.filter { $0.1 > $0.0 }.map { $0.0..<$0.1 }
    }

    /// Lovable's form: an intro until the first cut about two bars in, a break under words alone in the second half,
    /// an outro from the closing or the trailing words.
    static func groove(_ shots: [Shot], grid: BeatGrid, closing: (start: Double, hit: Double?)?) -> BeatForm {
        let end = shots.last?.end ?? 0
        var form = BeatForm(drop: drop(after: shots, grid: grid, end: end), end: end)
        form.ending(shots, grid: grid, closing: closing)
        let stop = form.outro ?? end
        let body = (form.drop + 2 * grid.bar)..<(stop - grid.beat)
        let breaks = shots.filter { shot in
            shot.isWords && shot.start >= max(end / 2, body.lowerBound) && shot.end <= body.upperBound
                && grid.nearest(shot.end) - grid.nearest(shot.start) >= SoundRules.shortestBreak * grid.beat - 1e-6
        }
        if let shot = breaks.min(by: { abs($0.start - SoundRules.breakPlace * end) < abs($1.start - SoundRules.breakPlace * end) }) {
            form.breaks = [grid.nearest(shot.start)..<grid.nearest(shot.end)]
        }
        return form
    }

    /// The Spotify Jam's form: drums from the first beat, a beat's dip before the cut nearest the middle, to the end.
    static func house(_ shots: [Shot], grid: BeatGrid, closing: (start: Double, hit: Double?)?) -> BeatForm {
        let end = shots.last?.end ?? 0
        var form = BeatForm(drop: grid.phase, end: end)
        form.lastHit = closing.map { $0.hit ?? $0.start }.map(grid.nearest) ?? trailingWords(in: shots, end: end).last.map { grid.nearest($0.start) }
        let window = (SoundRules.dipWindow.lowerBound * end)...(SoundRules.dipWindow.upperBound * end)
        let cuts = shots.dropFirst().map(\.start).filter { window.contains($0) && $0 - 2 * grid.bar >= form.drop }
        if let cut = cuts.min(by: { abs($0 - end / 2) < abs($1 - end / 2) }) {
            let landing = grid.nearest(cut)
            form.breaks = [(landing - grid.beat)..<landing]
        }
        return form
    }

    /// The first cut between ``SoundRules/earliestDrop`` and ``SoundRules/latestDrop`` bars, on a whole bar from the first
    /// beat if one is; two bars in without one; the first beat in a film under four bars.
    private static func drop(after shots: [Shot], grid: BeatGrid, end: Double) -> Double {
        guard end >= grid.phase + 4 * grid.bar else { return grid.phase }
        let window = (grid.phase + SoundRules.earliestDrop * grid.bar)...(grid.phase + SoundRules.latestDrop * grid.bar)
        let cuts = shots.dropFirst().map(\.start).filter { window.contains(grid.nearest($0)) }
        // A cut on its beat, on a bar if one is: the drums come in with the picture
        let landed = cuts.filter { abs(grid.nearest($0) - $0) <= SoundRules.beatTolerance }.map(grid.nearest)
        let onBar = landed.first { grid.beats(to: $0).isMultiple(of: 4) }
        return onBar ?? landed.first ?? cuts.first.map(grid.nearest) ?? grid.phase + 2 * grid.bar
    }

    /// The outro from the closing, or from the trailing scenes of words and logos; its last hit on the logo.
    private mutating func ending(_ shots: [Shot], grid: BeatGrid, closing: (start: Double, hit: Double?)?) {
        // At most four bars: a film ending on a statement, a tagline and its words kept its drums through the first two
        let earliest = max(SoundRules.outroFrom * end, drop + 2 * grid.bar, end - SoundRules.longestOutro * grid.bar)
        // No drums after it, so on the cut itself, as the hit on the logo
        if let closing, closing.start >= drop + 2 * grid.bar {
            outro = closing.start
            lastHit = closing.hit
            return
        }
        let words = Self.trailingWords(in: shots, end: end).filter { $0.start >= earliest }
        guard let first = words.first else { return }
        outro = first.start
        lastHit = words.count > 1 ? words.last?.start : nil
    }

    /// The scenes at the end that are words alone, in order.
    private static func trailingWords(in shots: [Shot], end: Double) -> [Shot] {
        Array(shots.reversed().prefix { $0.isWords }.reversed())
    }
}
