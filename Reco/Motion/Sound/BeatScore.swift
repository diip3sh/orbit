//
//  BeatScore.swift
//  Reco
//

import Foundation

/// A beat score's chords and cues (spec 0015): drums, bass, keys or stabs and a pumping pad, played on a grid
/// fitted to the cuts in the parts a ``BeatForm`` lays out. Its cues are on the grid, not on frames: music snapped to
/// 30 fps would swing by up to 33 ms.
nonisolated struct BeatScore {
    let style: BeatStyle
    let grid: BeatGrid
    let form: BeatForm

    private(set) var cues: [SoundCue] = []
    private(set) var chords: [SoundCueSheet.Chord] = []
    private var random = SeededRandom(seed: 0xBEA7)

    init(style: BeatStyle, grid: BeatGrid, form: BeatForm) {
        (self.style, self.grid, self.form) = (style, grid, form)
        intro()
        for (index, segment) in form.segments.enumerated() {
            body(segment, isFirst: index == 0)
        }
        for gap in form.breaks {
            lift(gap)
        }
        outro()
    }

    private var sixteenth: Double {
        grid.beat / 4
    }

    // MARK: - Parts

    /// Before the drop: the intro's chords, dark and steady, a voice sliding in twice, a riser into the drop.
    private mutating func intro() {
        guard form.drop > 0.05 else { return }
        if style.intro.isEmpty {
            addPad(style.progression[0], from: 0, to: form.drop, brightness: style.brightness.intro, pumped: false)
            return
        }
        // Two bars a chord, counted back from the drop so it lands on the body's first
        let span = 2 * grid.bar
        var start = form.drop
        var index = 0
        while start > 0.05 {
            let from = max(start - span, 0)
            let harmony = style.intro[(style.intro.count - 1 - index % style.intro.count)]
            addPad(harmony, from: from, to: start, brightness: style.brightness.intro, pumped: false, level: style.levels.pad + 2)
            start = from
            index += 1
        }
        // The reference's intro has pitched swoops (3.8–5.5 s), but sung by a synthesized voice they read as a toy: the
        // user found the groove "not good at all". The pad and the riser carry it.
        riser(into: form.drop)
    }

    /// The drums, bass and chords from `segment`'s start, its bars counted from there.
    private mutating func body(_ segment: Range<Double>, isFirst: Bool) {
        impact(at: segment.lowerBound, big: isFirst && form.drop > 0.05)
        let bars = Int(((segment.upperBound - segment.lowerBound) / grid.bar).rounded(.up))
        for bar in 0..<bars {
            let start = segment.lowerBound + Double(bar) * grid.bar
            guard start < segment.upperBound - 1e-6 else { break }
            let harmony = style.progression[bar % style.progression.count]
            addPad(harmony, from: start, to: min(start + grid.bar, segment.upperBound), brightness: style.brightness.body, pumped: true)
            if bar > 0, bar.isMultiple(of: 8) {
                add(.drum(.crash), at: start, level: style.levels.crash - 3, pan: 0.2, send: 0.3)
            }
            phrase(bar: bar, from: start, harmony: harmony, within: segment, fills: isFillBar(bar, start: start, in: segment))
        }
    }

    /// Whether `bar` ends in a fill: every ``BeatStyle/fillBars`` bars, and the last before a break, return or outro.
    private func isFillBar(_ bar: Int, start: Double, in segment: Range<Double>) -> Bool {
        let last = start + grid.bar >= segment.upperBound - 1e-6
        return (last && segment.upperBound < form.end - 1e-6) || (bar + 1).isMultiple(of: style.fillBars)
    }

    /// One bar of the two-bar phrase: its half of every part, inside `segment`.
    private mutating func phrase(bar: Int, from start: Double, harmony: BeatStyle.Harmony, within segment: Range<Double>, fills: Bool) {
        let half = (bar % 2) * 16
        let steps = half..<(half + 16)
        let sixteenth = sixteenth
        let time = { (step: Int) in start + Double(step - half) * sixteenth }
        let inside = { (step: Int) in time(step) < segment.upperBound - 1e-6 }
        let levels = style.levels
        for hit in style.kicks where steps.contains(hit.step) && inside(hit.step) {
            add(.drum(style.kick), at: time(hit.step), level: levels.kick + hit.level, send: 0)
        }
        // A fill takes the bar's last beat from the snares
        let fillFrom = half + 12
        for hit in style.snares where steps.contains(hit.step) && inside(hit.step) && !(fills && hit.step >= fillFrom) {
            add(.drum(.snare), at: time(hit.step), level: levels.snare + hit.level, pan: 0.04, send: 0.26)
        }
        for hit in style.claps where steps.contains(hit.step) && inside(hit.step) && !(fills && hit.step >= fillFrom && style.snares.isEmpty) {
            add(.drum(.clap), at: time(hit.step), level: levels.clap + hit.level, send: 0.3)
        }
        if fills {
            let drum: SoundCue.Drum = style.snares.isEmpty ? .clap : .snare
            for hit in style.fill where inside(half + hit.step) {
                add(.drum(drum), at: time(half + hit.step), level: (drum == .snare ? levels.snare : levels.clap) + hit.level, pan: 0.04, send: 0.2)
            }
        }
        for hit in style.hats where steps.contains(hit.step) && inside(hit.step) {
            let jitter = random.uniform(-SoundRules.hatJitter.time...SoundRules.hatJitter.time)
            // Off the middle, the downbeat's to one side and the rest to the other, as a kit's hats sit in a stereo pair
            add(.drum(.hat), at: time(hit.step) + jitter, level: levels.hat + hit.level + random.uniform(-SoundRules.hatJitter.level...0),
                pan: hit.step.isMultiple(of: 4) ? -SoundRules.hatPan : SoundRules.hatPan, send: 0.14)
        }
        for hit in style.openHats where steps.contains(hit.step) && inside(hit.step) {
            add(.drum(.openHat), at: time(hit.step), level: levels.openHat + hit.level, pan: -SoundRules.hatPan, send: 0.14)
        }
        bass(steps: steps, time: time, inside: inside, harmony: harmony, segmentEnd: segment.upperBound)
        let sung = harmony.notes.sorted().map { Double($0 + 12) }
        for chop in style.chops where steps.contains(chop.step) && inside(chop.step) && sung.indices.contains(max(chop.from, chop.onto)) {
            add(.vox(from: sung[chop.from], onto: sung[chop.onto], length: Double(chop.length) * sixteenth), at: time(chop.step),
                level: levels.chords - 5, pan: chop.step < 16 ? -0.2 : 0.2, send: 0.35)
        }
        for (order, hit) in style.chordHits.enumerated() where steps.contains(hit.step) && inside(hit.step) {
            let notes = harmony.notes.map(Double.init)
            let long = order == 0
            let length = long ? grid.bar : 2.2 * sixteenth
            let voice: SoundCue.Voice = style.voicing == .keysAndSub ? .keys(notes: notes, length: long ? grid.bar * 0.95 : length + 0.2)
                : .stab(notes: notes, length: length)
            add(voice, at: time(hit.step), level: levels.chords + hit.level, pan: order.isMultiple(of: 2) ? -0.12 : 0.12, send: 0.28)
        }
    }

    /// The bassline's notes in `steps`, each until the next or the segment's end.
    private mutating func bass(steps: Range<Int>, time: (Int) -> Double, inside: (Int) -> Bool, harmony: BeatStyle.Harmony, segmentEnd: Double) {
        let line = style.bassline
        for (index, note) in line.enumerated() where steps.contains(note.step) && inside(note.step) {
            let next = line[(index + 1) % line.count].step
            // To the next note round the phrase: a whole phrase when it's the only one
            let gap = Double((next - note.step + 31) % 32 + 1) * sixteenth
            let length = min(gap, segmentEnd - time(note.step))
            let pitch = Double(harmony.bass + note.interval)
            let previous = line[(index + line.count - 1) % line.count]
            let voice: SoundCue.Voice = style.voicing == .keysAndSub
                ? .sub(note: pitch, from: note.slides ? Double(harmony.bass + previous.interval) : nil, length: length * 0.95)
                : .bass(note: pitch, length: min(length * 0.8, 0.22))
            add(voice, at: time(note.step), level: style.levels.bass, send: 0.02)
        }
    }

    /// A break: the kick and bass out, the hats on, the lift's chords, a riser into the return; a beat's dip: nothing but
    /// the pad and the riser.
    private mutating func lift(_ gap: Range<Double>) {
        let isDip = gap.upperBound - gap.lowerBound < 2 * grid.beat - 1e-6
        var start = gap.lowerBound
        var index = 0
        while start < gap.upperBound - 1e-6 {
            let until = min(start + grid.bar, gap.upperBound)
            addPad(style.lift[index % style.lift.count], from: start, to: until, brightness: style.brightness.lift, pumped: false, level: style.levels.pad + 1)
            if !isDip {
                for step in stride(from: 0, to: 16, by: 2) where start + Double(step) * sixteenth < gap.upperBound - 1e-6 {
                    add(.drum(.hat), at: start + Double(step) * sixteenth, level: style.levels.hat - (step.isMultiple(of: 4) ? 6 : 3),
                        pan: step.isMultiple(of: 4) ? -SoundRules.hatPan : SoundRules.hatPan, send: 0.14)
                }
            }
            start = until
            index += 1
        }
        if !isDip {
            add(.drum(.crash), at: gap.lowerBound, level: style.levels.crash - 2, pan: -0.2, send: 0.4)
        }
        riser(into: gap.upperBound)
    }

    /// Drums out under the end words: the held chord, then home on the last hit, ringing to the end.
    private mutating func outro() {
        guard let outro = form.outro else {
            if let hit = form.lastHit {
                add(.drum(.crash), at: hit, level: style.levels.crash, pan: 0.15, send: 0.4)
            }
            return
        }
        let home = form.lastHit ?? form.end
        add(.drum(.crash), at: outro, level: style.levels.crash - 2, pan: 0.15, send: 0.45)
        addPad(style.held, from: outro, to: home, brightness: style.brightness.outro, pumped: false, level: style.levels.pad + 2)
        // The held chord struck once as the drums stop
        add(chordVoice(style.held, length: 1.6), at: outro, level: style.levels.chords - 1, send: 0.45)
        if let hit = form.lastHit, hit < form.end - 0.05 {
            if hit - outro > 1.2 * grid.bar {
                riser(into: hit)
            }
            impact(at: hit, big: true)
            addPad(style.home, from: hit, to: form.end, brightness: style.brightness.outro, pumped: false, level: style.levels.pad + 3, release: 2)
            add(chordVoice(style.home, length: 2.4), at: hit, level: style.levels.chords, send: 0.5)
            add(.sub(note: Double(style.home.bass), from: nil, length: min(form.end - hit, 2.2)), at: hit, level: style.levels.bass - 1, send: 0)
        }
    }

    // MARK: - Pieces

    private func chordVoice(_ harmony: BeatStyle.Harmony, length: Double) -> SoundCue.Voice {
        let notes = harmony.notes.map(Double.init)
        return style.voicing == .keysAndSub ? .keys(notes: notes, length: length) : .stab(notes: notes, length: min(length, 0.9))
    }

    /// A crash on a drop or a return; on the first drop and the last hit, a low hit under it.
    private mutating func impact(at time: Double, big: Bool) {
        add(.drum(.crash), at: time, level: style.levels.crash + (big ? 1 : 0), pan: -0.1, send: 0.4)
        guard big else { return }
        let hit = SoundRules.dropImpact
        add(.thump(high: hit.high, low: hit.low, length: hit.length, decay: hit.decay), at: time, level: style.levels.impact, send: 0.2)
    }

    /// Noise swept up into `time`, at most two bars and ``SoundRules/dropRiser``'s length.
    private mutating func riser(into time: Double) {
        let shape = SoundRules.dropRiser
        let length = min(shape.length, 2 * grid.bar, max(time - 0.05, 0))
        guard length > 0.3 else { return }
        add(.riser(length: length, low: shape.low, high: shape.high, power: shape.power), at: time, level: style.levels.riser, send: 0.3)
    }

    private mutating func addPad(
        _ harmony: BeatStyle.Harmony, from start: Double, to end: Double, brightness: Double, pumped: Bool, level: Double? = nil, release: Double = 0.35
    ) {
        guard end > start + 1e-6 else { return }
        var chord = SoundCueSheet.Chord(notes: harmony.notes, bass: nil, start: start, end: end, level: level ?? style.levels.pad,
                                        attack: pumped ? 0.02 : 0.3, release: release, brightness: brightness)
        chord.pump = pumped ? SoundCueSheet.Pump(period: grid.beat, depth: style.pump) : nil
        // A chord already held carries on without a new attack
        if let last = chords.last, last.notes == chord.notes, abs(last.end - start) < 1e-6, last.pump == chord.pump, last.brightness == brightness,
           last.level == chord.level {
            chords[chords.count - 1].end = end
            return
        }
        chords.append(chord)
    }

    private mutating func add(_ voice: SoundCue.Voice, at time: Double, level: Double, pan: Double = 0, send: Double = 0.15) {
        guard time >= 0, time < form.end else { return }
        cues.append(SoundCue(voice: voice, part: .score, time: time, level: level, pan: pan, send: send, seed: random.next()))
    }
}
