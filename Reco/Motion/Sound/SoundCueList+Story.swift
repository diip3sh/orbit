//
//  SoundCueList+Story.swift
//  Reco
//

import Foundation

/// A story film's transitions (spec 0015), each with its own sound: the look's seams, the ring into the logo, a card stacking
/// over a scene, a click opening into the next, a wash as something is sent, a swap to done.
nonisolated extension SoundCueList {

    /// The opening's arrival, every seam drawn in a look's language, and every stack and expand.
    mutating func seams(of plan: MotionPlan, before end: Double) {
        for (index, scene) in plan.scenes.enumerated() where scene.start < end {
            if index == 0, let arrival = scene.arrival {
                seam(arrival.seam, at: scene.arrivesAt, lasting: arrival.duration)
            }
            if index > 0, let transition = scene.transition {
                seam(transition.seam, at: scene.start, lasting: transition.duration)
            }
        }
    }

    private mutating func seam(_ seam: MotionSeam, at time: Double, lasting duration: Double) {
        switch seam {
        case .dither:
            add(.bits(length: duration), .effects, at: time, level: SoundRules.bitsLevel, send: 0.25)
            let (glass, thump) = (SoundRules.ditherLanding, SoundRules.ditherThump)
            let landing = time + glass.at * duration
            add(.glass(note: glass.note, length: glass.length, brightness: glass.brightness), .effects, at: landing, level: glass.level, pan: 0.1, send: 0.45)
            add(.thump(high: thump.high, low: thump.low, length: thump.length, decay: thump.decay), .effects, at: landing, level: thump.level, send: 0.1)
        case .glow:
            let (riser, glass) = (SoundRules.glowRiser, SoundRules.glowGlass)
            add(.riser(length: riser.length, low: riser.low, high: riser.high, power: riser.power), .effects, at: time + riser.peak * duration,
                level: riser.level, send: 0.3)
            add(.glass(note: glass.note, length: glass.length, brightness: glass.brightness), .effects, at: time + riser.peak * duration,
                level: glass.level, pan: -0.1, send: 0.45)
        case .ring:
            let (riser, thump, glass) = (SoundRules.ringRiser, SoundRules.ringThump, SoundRules.ringGlass)
            add(.riser(length: riser.length, low: riser.low, high: riser.high, power: riser.power), .effects, at: time, level: riser.level, send: 0.3)
            add(.thump(high: thump.high, low: thump.low, length: thump.length, decay: thump.decay), .effects, at: time, level: thump.level, send: 0.2)
            for (index, note) in glass.notes.enumerated() {
                add(.glass(note: note, length: glass.length, brightness: 1), .effects, at: time, level: glass.levels[index], pan: glass.pans[index],
                    send: 0.55, offset: glass.delay * Double(index + 1))
            }
        case .stack:
            let (swish, landing) = (SoundRules.stackSwish, SoundRules.stackLanding)
            add(.swish(length: swish.length), .effects, at: time, level: swish.level, send: swish.send)
            add(.thump(high: landing.high, low: landing.low, length: landing.length, decay: landing.decay), .effects, at: time + landing.at * duration,
                level: landing.level, send: 0.1)
        case .expand:
            let (riser, glass) = (SoundRules.expandRiser, SoundRules.expandGlass)
            let open = time + riser.peak * duration
            add(.riser(length: riser.length, low: riser.low, high: riser.high, power: riser.power), .effects, at: open, level: riser.level, send: 0.3)
            add(.glass(note: glass.note, length: glass.length, brightness: glass.brightness), .effects, at: open, level: glass.level, pan: 0.1, send: 0.45)
        default:
            break
        }
    }

    /// A story move's sound: a wash's shimmer, a swap's chime.
    mutating func story(_ kind: MotionMove.Kind, at time: Double) {
        if kind == .wash {
            wash(at: time)
        } else if kind == .show {
            done(at: time)
        }
    }

    /// A wash's shimmer, rising with its front.
    private mutating func wash(at time: Double) {
        let (shimmer, glass) = (SoundRules.washShimmer, SoundRules.washGlass)
        let crossed = time + shimmer.crossed
        add(.riser(length: shimmer.length, low: shimmer.low, high: shimmer.high, power: shimmer.power), .effects, at: crossed, level: shimmer.level,
            send: 0.35)
        add(.glass(note: glass.note, length: glass.length, brightness: glass.brightness), .effects, at: crossed, level: glass.level, pan: 0.2, send: 0.5)
    }

    /// A swap to done's chime, once for everything that swaps together.
    private mutating func done(at time: Double) {
        let moment = frame(time)
        let chime = SoundRules.doneChime
        let chimed = list.contains { cue in
            guard case .blip(let note, _) = cue.voice else { return false }
            return note == chime.notes[0] && abs(cue.time - moment) < SoundRules.swapTogether
        }
        guard !chimed else { return }
        for (index, note) in chime.notes.enumerated() {
            add(.blip(note: note, length: chime.length), .effects, at: time, level: chime.levels[index], pan: index == 0 ? -0.1 : 0.1, send: 0.35,
                offset: chime.gap * Double(index))
        }
    }
}
