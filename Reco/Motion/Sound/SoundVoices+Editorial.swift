//
//  SoundVoices+Editorial.swift
//  Reco
//

import Accelerate

/// An editorial film's own voice (spec 0017), and the textures it shares with story films' seams.
nonisolated extension SoundVoices {

    /// ElevenLabs' digital tick: a 10.2 kHz tone in 0.3 ms, 20 dB down within 3–17 ms (a 4 ms time constant), 30 ms long.
    static func tick() -> [Float] {
        let times = SoundSignal.times(SoundSignal.count(tickLength))
        let tone = SoundSignal.sine(tickPitch, count: times.count)
        return SoundSignal.peakNormalized(vDSP.multiply(vDSP.multiply(tone, SoundSignal.decay(times, tickDecay)), SoundSignal.ramp(times, over: tickAttack)))
    }

    /// The high, dry sounds of a transition and of type: a dither seam's bits, an editorial tick.
    static func texture(_ voice: SoundCue.Voice, random: inout SeededRandom) -> Sound {
        if case .bits(let length) = voice {
            return .stereo(bits(length: length, random: &random))
        }
        return .mono(tick())
    }

    static let tickPitch = 10_200.0
    static let tickAttack = 0.0003
    static let tickDecay = 0.004
    static let tickLength = 0.03
}
