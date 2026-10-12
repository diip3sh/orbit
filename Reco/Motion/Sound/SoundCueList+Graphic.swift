//
//  SoundCueList+Graphic.swift
//  Reco
//

import Foundation

/// A graphic seam's sound (spec 0019); a flow's is a flip's, air as the layers cross and a landing (spec 0020).
nonisolated extension SoundCueList {

    mutating func graphic(_ seam: MotionSeam, at time: Double, lasting duration: Double) {
        let swish = SoundRules.graphicSwish
        switch seam {
        case .bars, .slats, .tiles:
            add(.swish(length: swish.length), .effects, at: time + swish.at * duration, level: swish.level, send: swish.send)
            let landing = SoundRules.barLanding
            let count = seam == .bars ? 3 : 1
            for index in 0..<count {
                let lands = time + duration * (0.55 + TransitionRenderer.barStagger * Double(index))
                add(.thump(high: landing.high, low: landing.low, length: landing.length, decay: landing.decay), .effects, at: lands,
                    level: landing.level - landing.step * Double(index), send: 0.1)
            }
        case .iris, .liquid:
            let (riser, glass) = (SoundRules.openRiser, SoundRules.openGlass)
            add(.riser(length: riser.length, low: riser.low, high: riser.high, power: riser.power), .effects, at: time + riser.peak * duration,
                level: riser.level, send: 0.3)
            add(.glass(note: glass.note, length: glass.length, brightness: glass.brightness), .effects, at: time + glass.at * duration,
                level: glass.level, pan: 0.1, send: 0.45)
        case .spin, .split, .stretch:
            add(.whoosh, .effects, at: time + duration / 2, level: SoundRules.graphicWhoosh, send: 0.2)
        case .flip, .cube, .flow:
            add(.swish(length: swish.length), .effects, at: time + swish.at * duration, level: swish.level, send: swish.send)
            let landing = SoundRules.stackLanding
            add(.thump(high: landing.high, low: landing.low, length: landing.length, decay: landing.decay), .effects, at: time + 0.9 * duration,
                level: landing.level, send: 0.1)
        case .glitch, .pixelate:
            add(.bits(length: duration), .effects, at: time, level: SoundRules.bitsLevel, send: 0.2)
        case .flash:
            let (thump, glass) = (SoundRules.flashThump, SoundRules.flashGlass)
            let peak = time + TransitionRenderer.flashPeak * duration
            add(.thump(high: thump.high, low: thump.low, length: thump.length, decay: thump.decay), .effects, at: peak, level: thump.level, send: 0.15)
            add(.glass(note: glass.note, length: glass.length, brightness: glass.brightness), .effects, at: peak, level: glass.level, send: 0.4)
        default:
            break
        }
    }
}
