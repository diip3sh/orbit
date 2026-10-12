//
//  SoundCueSheet+Score.swift
//  Reco
//

import Foundation

// MARK: - The body's chords

nonisolated extension SoundCueSheet {

    /// A chord a shot until `end`: changing just before each cut (every second cut when a scene is shorter
    /// than ``SoundRules/shortestScene``) and on each whip's landing within a scene, walked back from the tonic.
    static func bodyChords(of plan: MotionPlan, whips: [CameraWhip], until end: Double, closes: Bool) -> [Chord] {
        guard end > 0 else { return [] }
        let starts = plan.scenes.map(\.start).filter { $0 < end }
        var changes = starts.dropFirst().map { $0 - SoundRules.chordLead }
        if zip(starts, starts.dropFirst() + [end]).contains(where: { $1 - $0 < SoundRules.shortestScene }) {
            changes = changes.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element)
        }
        let landings = whips.filter { !$0.crossesCut }.map { SoundRules.frame($0.landing, frameRate: plan.frameRate) }
        for landing in landings where ([0, end] + changes).allSatisfy({ abs($0 - landing) >= SoundRules.shortestChord }) {
            changes = (changes + [landing]).sorted()
        }
        let count = changes.count + 1
        let middle = closes && count > 1 ? 1..<(count - 1) : 1..<count
        return (0..<count).map { index in
            let harmony = SoundRules.progression[((index - (count - 1)) % 4 + 4) % 4]
            var chord = Chord(notes: harmony.notes, bass: harmony.bass, start: index == 0 ? 0 : changes[index - 1],
                              end: index == count - 1 ? end : changes[index], level: SoundRules.middle.level.lowerBound)
            if index == 0 {
                (chord.level, chord.attack, chord.swell, chord.brightness) = SoundRules.opening
            } else if middle.contains(index) {
                let share = middle.count > 1 ? Double(index - middle.lowerBound) / Double(middle.count - 1) : 0
                chord.level = interpolated(SoundRules.middle.level, share)
                chord.brightness = interpolated(SoundRules.middle.brightness, share)
            } else {
                (chord.level, chord.attack, chord.swell, chord.brightness, chord.release) = SoundRules.last
            }
            if closes && index == count - 1 {
                // Into black, cut dead with the picture
                chord.release = SoundRules.last.release
            } else if closes && index == count - 2 && count > 2 {
                chord.release = SoundRules.beforeLastRelease
            }
            return chord
        }
    }

    private static func interpolated(_ range: ClosedRange<Double>, _ share: Double) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * share
    }
}

// MARK: - The closing

/// The closing as New Raycast's is scored: a hit on the cut to black; under the words the IV chord and a
/// felt arpeggio, its first note on each word's frame and no sound of a word's own; I at the slide, vi at
/// the dimmed line, V at the logo; everything fading, the logo the quietest.
nonisolated struct ClosingCues {

    /// When the closing starts, in seconds into the video, and its parts' frames.
    let start: Double
    let words: [Double]
    let slide, settled: Double
    let line: Double?
    let logo: Double?

    init?(plan: MotionPlan, document: MotionDocument) {
        guard let index = document.scenes.firstIndex(where: { $0.shot?.kind == .closing }), plan.scenes.indices.contains(index),
              let shot = document.scenes[index].shot, shot.text?.isEmpty == false else { return nil }
        let count = (shot.items ?? []).compactMap(\.text).filter { !$0.isEmpty }.count
        guard count > 0 else { return nil }
        let times = ShotLayout.ClosingTimes(words: count)
        let begin = plan.scenes[index].start
        let frame = { SoundRules.frame(begin + $0, frameRate: plan.frameRate) }
        start = begin
        words = times.words.map(frame)
        (slide, settled) = (frame(times.slide), frame(times.settled))
        line = shot.detail?.isEmpty == false ? frame(times.underline) : nil
        logo = shot.asset == nil ? nil : frame(times.logo)
    }

    /// IV from the cut to black, then a chord at each step, each in a beat before it shows.
    func chords(until end: Double) -> [SoundCueSheet.Chord] {
        let lead = SoundRules.stepLead
        let steps: [(chord: SoundCueSheet.Chord, from: Double)] = [(SoundRules.wordsChord, start), (SoundRules.slideChord, slide - lead)]
            + (line.map { [(SoundRules.lineChord, $0 - lead)] } ?? []) + (logo.map { [(SoundRules.logoChord, $0 - lead)] } ?? [])
        return steps.enumerated().map { index, step in
            var chord = step.chord
            chord.start = step.from
            // The words' chord rings out under the slide's; the others hand over as the next comes in
            chord.end = index == 0 ? slide : (index + 1 < steps.count ? steps[index + 1].from + lead : end)
            return chord
        }
    }

    func add(to cues: inout SoundCueList) {
        let riser = SoundRules.blackRiser
        cues.add(.riser(length: riser.length, low: riser.low, high: riser.high, power: riser.power), .score, at: start, level: riser.level)
        let hit = SoundRules.blackThump
        cues.add(.thump(high: hit.high, low: hit.low, length: hit.length, decay: hit.decay), .score, at: start, level: hit.level, send: 0.25)
        addArpeggio(to: &cues)
        for (time, felt) in [(line, SoundRules.lineFelt), (logo, SoundRules.logoFelt)] {
            guard let time else { continue }
            for (index, note) in felt.notes.enumerated() {
                cues.add(.felt(note: note, length: felt.length), .score, at: time, level: felt.level - Double(index), pan: felt.pans[index],
                         send: felt.send, offset: felt.roll * Double(index))
            }
        }
    }

    /// Four notes a word, the first on its frame, then a note every 0.105 s from the last word until the
    /// lockup settles.
    private func addArpeggio(to cues: inout SoundCueList) {
        let arpeggio = SoundRules.arpeggio
        var steps = zip(words, words.dropFirst()).flatMap { word, next in (0..<4).map { (word, (next - word) * Double($0) / 4) } }
        if let last = words.last {
            steps += stride(from: 0, to: settled - SoundRules.stepLead - last, by: arpeggio.after).map { (last, $0) }
        }
        for (index, step) in steps.enumerated() {
            let time = step.0 + step.1
            let figure = (time >= slide ? arpeggio.slide : arpeggio.words)[(index / 4) % 2]
            let level = (index.isMultiple(of: 4) ? arpeggio.accent : arpeggio.level) + fading(at: time) + cues.random.uniform(-arpeggio.jitter...arpeggio.jitter)
            cues.add(.felt(note: figure[index % 4], length: arpeggio.length), .score, at: step.0, level: level,
                     pan: index.isMultiple(of: 2) ? -arpeggio.pan : arpeggio.pan, send: arpeggio.send, offset: step.1)
        }
    }

    /// 0 dB at the first word, thinning out to the last, then further until the lockup settles.
    private func fading(at time: Double) -> Double {
        let (first, last) = (words.first ?? start, words.last ?? start)
        let fade = SoundRules.arpeggioFade
        if time <= last {
            return last > first ? fade.lastWord * (time - first) / (last - first) : 0
        }
        let share = min((time - last) / max(settled - last, 1e-6), 1)
        return fade.lastWord + (fade.settled - fade.lastWord) * share
    }
}
