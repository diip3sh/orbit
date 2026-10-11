//
//  SoundCueSheet+Editorial.swift
//  Reco
//

import Foundation

/// An editorial film's score (spec 0017, ``SoundRules`` editorial numbers): sections of the edit, each with its chord, the
/// cues on their cuts and in them.
nonisolated extension SoundCueSheet {

    /// What a section of the edit is to the score.
    enum EditorialRole: Equatable {
        case opening, body, breakdown, lift, peak, tail
    }

    /// The scenes that begin sections: the first, every cut at least ``SoundRules/shortestSection`` after its section began,
    /// and the last scene, the end card.
    static func editorialSections(of starts: [Double]) -> [Int] {
        var sections = [0]
        for index in starts.indices.dropFirst() {
            guard let begun = sections.last else { continue }
            if index == starts.count - 1 || starts[index] - starts[begun] >= SoundRules.shortestSection {
                sections.append(index)
            }
        }
        return sections
    }

    /// The `count` sections' roles: the opening, then the body; the end card's tail last, the peak before it and the lift
    /// before that; with six or more, the breakdown the body's section that starts nearest the middle, after the build.
    static func editorialRoles(_ count: Int, starts: [Double], length: Double) -> [EditorialRole] {
        var roles = [EditorialRole](repeating: .body, count: count)
        roles[0] = .opening
        guard count > 1 else { return roles }
        roles[count - 1] = .tail
        if count > 2 {
            roles[count - 2] = .peak
        }
        if count > 4 {
            roles[count - 3] = .lift
        }
        if count >= 6, let middle = (2...(count - 4)).min(by: { abs(starts[$0] - length / 2) < abs(starts[$1] - length / 2) }) {
            roles[middle] = .breakdown
        }
        return roles
    }

    /// Spec 0017's score: dark wide pads a section, a sub boom and thump a sixteenth after each section's cut, ticks on the
    /// cuts between and on what types, a breakdown of the drone and the pad, the lift's echoing hit, the peak's major, and
    /// the end card's bursts over a tail.
    mutating func scoreEditorial(plan: MotionPlan, document: MotionDocument) {
        let starts = plan.scenes.map(\.start)
        let grid = BeatGrid.fitted(to: Array(starts.dropFirst()), tempo: SoundRules.editorialTempo)
        let hit = grid.beat / 4
        let sections = Self.editorialSections(of: starts)
        let roles = Self.editorialRoles(sections.count, starts: sections.map { starts[$0] }, length: length)
        var cues = SoundCueList(frameRate: plan.frameRate)
        var (body, returning) = (0, false)
        for (order, scene) in sections.enumerated() {
            let (start, role) = (starts[scene], roles[order])
            let next = order + 1 < sections.count ? starts[sections[order + 1]] - SoundRules.chordLead : length
            let harmony = Self.editorialHarmony(role, body: body, returning: returning)
            body += role == .body ? 1 : 0
            chords.append(Self.editorialChord(harmony, role: role, from: order == 0 ? 0 : start - SoundRules.chordLead, to: next))
            cues.section(EditorialSection(
                role: role, start: start, bass: harmony.bass, risesIn: order == 1, returns: returning && role == .body && body == 1,
                name: Self.nameTime(in: plan.scenes[scene]) ?? start + SoundRules.editorialBurst.name
            ), beat: grid.beat)
            if role == .breakdown {
                (returning, body) = (true, 0)
            }
        }
        // Ticks on the cuts inside sections, a sixteenth late as the film's
        for index in starts.indices.dropFirst() where !sections.contains(index) {
            cues.add(.tick, .score, at: starts[index] + hit, level: SoundRules.editorialTick.level, pan: SoundRules.editorialTick.pan)
        }
        cues.editorialEvents(of: plan, document: document)
        self.cues = cues.list.sorted { $0.time < $1.time }
        finish = SoundRules.editorialFinish
    }

    /// A section of the edit as the score marks it: its role, cut and chord's bass; whether it's the first after the opening
    /// (it rises in on air) or the body's return (louder); when the end card's name shows.
    struct EditorialSection {
        let role: EditorialRole
        let start: Double
        let bass: Int?
        let risesIn: Bool
        let returns: Bool
        let name: Double
    }

    /// A section's chord by its role: the body's walking through its list (the return's after the breakdown).
    private static func editorialHarmony(_ role: EditorialRole, body: Int, returning: Bool) -> (notes: [Int], bass: Int?) {
        switch role {
        case .opening: return (SoundRules.editorialOpening.notes, nil)
        case .breakdown: return (SoundRules.editorialBreakdown.notes, SoundRules.editorialBreakdown.bass)
        case .lift: return (SoundRules.editorialLift.notes, SoundRules.editorialLift.bass)
        case .peak, .tail: return (SoundRules.editorialTonic.notes, SoundRules.editorialTonic.bass)
        case .body:
            let list = returning ? SoundRules.editorialReturn : SoundRules.editorialBody
            return (list[body % list.count].notes, list[body % list.count].bass)
        }
    }

    /// A section's pad by its role, wide.
    private static func editorialChord(_ harmony: (notes: [Int], bass: Int?), role: EditorialRole, from start: Double, to end: Double) -> Chord {
        let pads = SoundRules.editorialPads
        let shape = switch role {
        case .opening: pads.opening
        case .body: pads.body
        case .breakdown: pads.breakdown
        case .lift: pads.lift
        case .peak: pads.peak
        case .tail: pads.tail
        }
        let until = role == .tail ? min(start + SoundRules.editorialTailLength, end) : end
        return Chord(notes: harmony.notes, bass: harmony.bass, start: start, end: until, level: shape.level, attack: shape.attack, release: role == .tail ? 0.3 : 0.5,
                     swell: shape.swell, brightness: shape.brightness, wide: true)
    }

    /// When the end card's name shows: its first revealed text's start, seconds into the video.
    private static func nameTime(in scene: MotionPlan.Scene) -> Double? {
        scene.layers.compactMap(\.reveal).map(\.start).min().map { scene.start + $0 }
    }
}

nonisolated extension SoundCueList {

    /// A section's cues a sixteenth after its cut by its role: none on the opening and the breakdown, the end card's bursts on
    /// its mark and its name, the lift's echo, a boom on the others, the peak's echoing too.
    mutating func section(_ section: SoundCueSheet.EditorialSection, beat: Double) {
        let moment = section.start + beat / 4
        switch section.role {
        case .opening, .breakdown:
            break
        case .tail:
            burst(at: section.start)
            burst(at: section.name)
        case .lift:
            echo(at: moment, beat: beat)
        case .body, .peak:
            let lift = section.returns ? SoundRules.editorialBoom.returnLift : 0
            boom(section.bass ?? SoundRules.editorialTonic.bass, at: moment, lift: lift, risesIn: section.risesIn)
            if section.role == .peak {
                echo(at: moment, beat: beat)
            }
        }
    }

    /// A section's boom: the chord's bass as a sub, an octave down while that stays over C♯1 with the bass itself under it,
    /// under a thump; air rising into the first.
    mutating func boom(_ bass: Int, at time: Double, lift: Double, risesIn: Bool) {
        let (boom, thump) = (SoundRules.editorialBoom, SoundRules.editorialThump)
        let note = Double(bass >= 37 ? bass - 12 : bass)
        add(.sub(note: note, from: nil, length: boom.length), .score, at: time, level: boom.level + lift, send: 0.05)
        if note < Double(bass) {
            add(.sub(note: Double(bass), from: nil, length: boom.length), .score, at: time, level: boom.level + lift + boom.octave, send: 0.05)
        }
        add(.thump(high: thump.high, low: thump.low, length: thump.length, decay: thump.decay), .score, at: time, level: thump.level + lift, send: 0.1)
        if risesIn {
            let riser = SoundRules.editorialRiser
            add(.riser(length: riser.length, low: riser.low, high: riser.high, power: riser.power), .score, at: time, level: riser.level, send: 0.3)
        }
    }

    /// The lift's low hit echoing a triplet eighth apart, each softer.
    mutating func echo(at time: Double, beat: Double) {
        let (echo, thump) = (SoundRules.editorialEcho, SoundRules.editorialThump)
        for index in 0..<echo.count {
            add(.thump(high: thump.high, low: thump.low, length: thump.length, decay: thump.decay), .score, at: time, level: thump.level + echo.fall * Double(index),
                pan: index.isMultiple(of: 2) ? -0.15 : 0.15, send: 0.3, offset: Double(index) * beat / 3)
        }
    }

    /// The end card's burst: air into a falling thump.
    mutating func burst(at time: Double) {
        let burst = SoundRules.editorialBurst
        add(.swish(length: burst.swish), .score, at: time, level: burst.level, send: 0.25)
        add(.thump(high: burst.high, low: burst.low, length: burst.length, decay: burst.decay), .score, at: time, level: burst.level, send: 0.15)
    }

    /// A tick for each character typed (no closer than the film's runs), each click and each blink; air rising as a card grows
    /// until it fills the frame.
    mutating func editorialEvents(of plan: MotionPlan, document: MotionDocument) {
        let typed: Set<TextReveal.Style> = [.type, .kinetic, .voice]
        let tick = SoundRules.editorialTick
        for scene in plan.scenes {
            for layer in scene.layers {
                if let reveal = layer.reveal, typed.contains(reveal.style) {
                    ticks(revealing: layer.parts.count, by: reveal, in: scene)
                }
                for click in layer.clicks {
                    add(.tick, .effects, at: scene.start + click.press, level: tick.level + 2)
                }
            }
        }
        // A graphic seam sounds as it does in any look
        for scene in plan.scenes.dropFirst() {
            if let transition = scene.transition, MotionSeam.graphic.contains(transition.seam) {
                graphic(transition.seam, at: scene.start, lasting: transition.duration)
            }
        }
        for (scene, planned) in zip(document.scenes, plan.scenes) {
            for layer in Self.flattened(scene.layers) {
                let context = MoveContext(sceneDuration: planned.duration, canvas: plan.canvas, layer: layer)
                for move in layer.moves where move.kind == .blink || move.kind == .grow {
                    let (start, duration) = MoveExpansion.timing(of: move, in: context)
                    if start < planned.duration {
                        editorialMove(move.kind, at: planned.start + start, lasting: duration)
                    }
                }
            }
        }
    }

    /// A tick a character as `reveal` types `parts` of them in `scene`, no closer than ``SoundRules/editorialTick``'s spacing.
    private mutating func ticks(revealing parts: Int, by reveal: TextReveal, in scene: MotionPlan.Scene) {
        let tick = SoundRules.editorialTick
        var last = -Double.infinity
        for index in 0..<parts {
            let time = scene.start + reveal.start(ofPart: index)
            guard time - last >= tick.spacing, time < scene.start + scene.duration else { continue }
            add(.tick, .effects, at: time, level: tick.level, pan: random.uniform(-tick.pan...tick.pan))
            last = time
        }
    }

    /// A blink's tick; a grow's air rising until the card fills the frame.
    private mutating func editorialMove(_ kind: MotionMove.Kind, at time: Double, lasting duration: Double) {
        let (tick, riser) = (SoundRules.editorialTick, SoundRules.editorialRiser)
        if kind == .blink {
            add(.tick, .effects, at: time, level: tick.level, pan: random.uniform(-tick.pan...tick.pan))
        } else {
            add(.riser(length: duration, low: riser.low, high: riser.high, power: riser.power), .effects, at: time + duration, level: riser.level, send: 0.3)
        }
    }
}
