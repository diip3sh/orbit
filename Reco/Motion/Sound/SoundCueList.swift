//
//  SoundCueList.swift
//  Reco
//

import Foundation

/// Cues as they're found, each on the frame that shows its moment, each with its own seed.
nonisolated struct SoundCueList {
    let frameRate: Int
    private(set) var list: [SoundCue] = []
    var random = SeededRandom(seed: 2026)

    /// Pops so far, each a step up the scale from the last.
    private var pops = 0

    /// Under a groove the music carries kinetic and voice type: no key a letter (spec 0015).
    var dropsKineticKeys = false

    init(frameRate: Int) {
        self.frameRate = frameRate
    }

    func frame(_ time: Double) -> Double {
        SoundRules.frame(time, frameRate: frameRate)
    }

    mutating func add(_ voice: SoundCue.Voice, _ part: SoundCue.Part, at time: Double, level: Double, pan: Double = 0, send: Double = 0.15, offset: Double = 0) {
        list.append(SoundCue(voice: voice, part: part, time: frame(time), offset: offset, level: level, pan: pan, send: send, seed: random.next()))
    }

    /// The first UI cut in.
    mutating func opening(at time: Double) {
        let hit = SoundRules.openingHit
        for index in hit.notes.indices {
            add(.glass(note: hit.notes[index], length: hit.length, brightness: 1), .score, at: time, level: hit.levels[index], pan: hit.pans[index], send: hit.send)
        }
        let thump = SoundRules.openingThump
        add(.thump(high: thump.high, low: thump.low, length: 0.7, decay: thump.decay), .score, at: time, level: thump.level, send: 0.1)
        add(.swish(length: SoundRules.openingSwish.length), .score, at: time, level: SoundRules.openingSwish.level, send: 0.2)
    }

    /// A quiet swish and thump on every plain cut but the one the first UI cuts in on: never on a whip, a
    /// seam drawn over both scenes, or into a closing. A story film's cuts are the swish alone, quieter: its transitions
    /// have their own sounds, and a low hit on every cut 2 s apart was the same sound everywhere.
    mutating func cuts(of plan: MotionPlan, document: MotionDocument, before end: Double, except opening: Double?, soft: Bool = false) {
        let plain: Set<MotionSeam> = [.cut, .blurCut, .zoomThrough, .cutOnMotion]
        for index in plan.scenes.indices.dropFirst() where plan.scenes[index].start < end && document.scenes.indices.contains(index) {
            let time = frame(plan.scenes[index].start)
            guard plain.contains(document.scenes[index].seam), time != opening else { continue }
            add(.swish(length: SoundRules.cutSwish.length), .effects, at: time, level: SoundRules.cutSwish.level + (soft ? SoundRules.softCut : 0),
                send: SoundRules.cutSwish.send)
            guard !soft else { continue }
            let thump = SoundRules.cutThump
            add(.thump(high: thump.high, low: thump.low, length: 0.7, decay: thump.decay), .effects, at: time, level: thump.level, send: 0.1)
        }
    }

    mutating func whips(_ whips: [SoundCueSheet.CameraWhip]) {
        for whip in whips {
            let riser = SoundRules.whipRiser
            add(.riser(length: riser.length, low: riser.low, high: riser.high, power: riser.power), .effects, at: whip.start, level: riser.level, send: 0.2)
            add(.whoosh, .effects, at: whip.peak, level: SoundRules.whooshLevel, send: 0.2)
            let thump = SoundRules.landingThump
            add(.thump(high: thump.high, low: thump.low, length: thump.length, decay: thump.decay), .effects, at: whip.landing, level: thump.level)
            let glass = SoundRules.landingGlass
            add(.glass(note: glass.note, length: glass.length, brightness: glass.brightness), .effects, at: whip.landing, level: glass.level,
                pan: 0.1, send: 0.5, offset: glass.delay)
        }
    }
}

// MARK: - Typing

nonisolated extension SoundCueList {

    /// Every key typed, results settled and arrow pressed in a scene's typed fields while the scene shows,
    /// and Enter where a selection is chosen before a cut.
    mutating func typing(in plan: MotionPlan, document: MotionDocument, before end: Double) {
        let assets = Dictionary(document.assets.map { ($0.id, $0) }) { first, _ in first }
        for (index, scene) in plan.scenes.enumerated() where scene.start < end && document.scenes.indices.contains(index) {
            let contents = MotionPlan.contents(of: document.scenes[index].layers)
            var chooses = false
            for (layer, content) in zip(scene.layers, contents) {
                guard let field = layer.typing, case .lifted(let lifted) = content, let text = assets[lifted.asset]?.typing?.text else { continue }
                type(text, into: field, at: scene.start, during: 0..<scene.duration)
                chooses = chooses || !field.presses.isEmpty
            }
            let next = index + 1
            if chooses, plan.scenes.indices.contains(next), plan.scenes[next].start < end {
                add(.key(.enter), .effects, at: plan.scenes[next].start - SoundRules.enterLead, level: SoundRules.enterLevel, send: 0.08)
            }
        }
    }

    /// `field`'s keys, settles and presses within `shown`, from `start` seconds into the video.
    private mutating func type(_ text: String, into field: TypedField, at start: Double, during shown: Range<Double>) {
        for (time, character) in zip(field.keys, text) where shown.contains(time) {
            let space = character == " "
            add(.key(space ? .space : .letter), .effects, at: start + time, level: space ? SoundRules.spaceLevel : SoundRules.keyLevel,
                pan: random.uniform(SoundRules.keyPan), send: SoundRules.keySend)
        }
        let notes = SoundRules.settleNotes
        let showsResults = (field.states.map(\.height).max() ?? 0) >= SoundRules.resultsGrowth * (field.states.first?.height ?? 0)
        for (order, state) in field.states.dropFirst().enumerated() where showsResults && shown.contains(state.time) {
            let note = notes[min(order, notes.count - 1)]
            add(.blip(note: note, length: 0.4), .effects, at: start + state.time, level: SoundRules.settleLevel, pan: 0.15, send: 0.4)
        }
        let blip = SoundRules.pressBlip
        for press in field.presses where shown.contains(press.time) {
            add(.key(.arrow), .effects, at: start + press.time, level: SoundRules.keyLevel, pan: 0.05, send: SoundRules.keySend)
            add(.blip(note: blip.note, length: blip.length), .effects, at: start + press.time, level: blip.level, pan: 0.2, send: 0.3, offset: blip.delay)
        }
    }
}

// MARK: - Motion design

nonisolated extension SoundCueList {

    /// Motion design's events (spec 0014): pops, presses and clicks, floods, bursts, kinetic keys and fast scrolls.
    mutating func design(in plan: MotionPlan, document: MotionDocument, before end: Double) {
        for (index, scene) in plan.scenes.enumerated() where scene.start < end && document.scenes.indices.contains(index) {
            let layers = Self.flattened(document.scenes[index].layers)
            for (layer, planned) in zip(layers, scene.layers) {
                let context = MoveContext(sceneDuration: scene.duration, canvas: plan.canvas, layer: layer)
                for move in layer.moves {
                    let timing = MoveExpansion.timing(of: move, in: context)
                    guard timing.start < scene.duration, scene.start + timing.start < end else { continue }
                    cue(move, at: scene.start + timing.start, lasting: timing.duration, in: context)
                }
                // A voice is dictated: Lovable's has no key a letter
                if let reveal = planned.reveal, reveal.style == .kinetic, !dropsKineticKeys, case .text(let text) = layer.content {
                    keys(text.text, revealed: reveal, from: scene.start, before: min(end, scene.start + scene.duration))
                }
            }
        }
    }

    /// `move`'s sound, if it has one, starting at `time` in the video.
    private mutating func cue(_ move: MotionMove, at time: Double, lasting duration: Double, in context: MoveContext) {
        switch move.kind {
        case .pop:
            let notes = SoundRules.popNotes
            add(.blip(note: notes[pops % notes.count], length: 0.3), .effects, at: time, level: SoundRules.popLevel, pan: 0.1, send: 0.3)
            pops += 1
        case .press, .click:
            add(.key(.letter), .effects, at: time, level: SoundRules.pressLevel, send: SoundRules.keySend)
        case .flood:
            flood(at: time, filling: time + duration * ShapeMorph.floodDip / (ShapeMorph.floodDip + ShapeMorph.floodFill))
        case .burst:
            let glass = SoundRules.burstGlass
            for note in glass.notes.indices {
                add(.glass(note: glass.notes[note], length: glass.length, brightness: 1.2), .effects, at: time, level: glass.levels[note],
                    pan: glass.pans[note], send: glass.send)
            }
        case .wash, .show:
            story(move.kind, at: time)
        case .scatter where move.target == nil:
            // A collage thrown out of its stack: a whoosh at its fastest, early in the throw
            add(.whoosh, .effects, at: time + duration * 0.3, level: SoundRules.whooshLevel - 6, send: 0.2)
        case .scroll:
            let distance = move.target.map { hypot($0.x - context.position.x, $0.y - context.position.y) } ?? 0
            if distance / duration / max(context.canvas.height, 1) > SoundRules.scrollWhoosh {
                add(.whoosh, .effects, at: time + duration / 2, level: SoundRules.whooshLevel - 6, send: 0.2)
            }
        default:
            break
        }
    }

    /// A riser into a flood's fill and a hit once it covers the frame.
    private mutating func flood(at start: Double, filling: Double) {
        let riser = SoundRules.floodRiser
        add(.riser(length: min(riser.length, filling - start + 0.2), low: riser.low, high: riser.high, power: riser.power), .effects, at: filling,
            level: riser.level, send: 0.2)
        let thump = SoundRules.floodThump
        add(.thump(high: thump.high, low: thump.low, length: thump.length, decay: thump.decay), .effects, at: filling + thump.after,
            level: thump.level, send: 0.15)
    }

    /// A key for each character a kinetic reveal types.
    private mutating func keys(_ text: String, revealed reveal: TextReveal, from start: Double, before end: Double) {
        for (index, character) in text.enumerated() where !character.isNewline {
            let time = start + reveal.start(ofPart: index)
            guard time < end else { break }
            let space = character == " "
            add(.key(space ? .space : .letter), .effects, at: time, level: space ? SoundRules.spaceLevel : SoundRules.keyLevel,
                pan: random.uniform(SoundRules.keyPan), send: SoundRules.keySend)
        }
    }

    /// Layers in the plan's order: each, then its group's.
    private static func flattened(_ layers: [MotionLayer]) -> [MotionLayer] {
        layers.flatMap { layer -> [MotionLayer] in
            if case .group(let children) = layer.content {
                return [layer] + flattened(children)
            }
            return [layer]
        }
    }
}
