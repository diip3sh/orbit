//
//  SoundVoices+Beat.swift
//  Reco
//

import Accelerate

/// A beat score's voices (spec 0015), generated as the score's are: drums from sines, squares and seeded noise,
/// basses and chords from a few partials each. Each is peak-normalized; its cue sets its level.
nonisolated extension SoundVoices {

    /// A beat score's voice.
    static func beat(_ voice: SoundCue.Voice, random: inout SeededRandom) -> Sound {
        let pitch = SoundSignal.frequency(ofNote:)
        switch voice {
        case .drum(let drum): return self.drum(drum, random: &random)
        case .sub(let note, let from, let length): return .mono(sub(pitch(note), from: from.map(pitch), length: length))
        case .bass(let note, let length): return .mono(bass(pitch(note), length: length))
        case .stab(let notes, let length): return .mono(stab(notes.map(pitch), length: length, random: &random))
        case .keys(let notes, let length): return .mono(keys(notes.map(pitch), length: length, random: &random))
        case .vox(let from, let onto, let length): return .mono(vox(from: pitch(from), onto: pitch(onto), length: length, random: &random))
        default: return .mono([])
        }
    }

    // MARK: - Drums

    /// A kick's shape: its pitch falling from `high` to `low` Hz (`drop` its time constant), held `hold`, then dying over
    /// `decay`; a click's share and the drive into tanh.
    private struct Kick {
        let low, high, drop, hold, decay, length: Double
        let click, drive: Float
    }

    static func drum(_ drum: SoundCue.Drum, random: inout SeededRandom) -> Sound {
        switch drum {
        case .kick: .mono(kick(Kick(low: 52, high: 210, drop: 0.028, hold: 0.04, decay: 0.11, length: 0.32, click: 0.4, drive: 1.8), random: &random))
        // The Spotify Jam's kicks are short blobs 40–130 Hz with gaps between: a long 808 tail was 6 dB too much sub
        case .houseKick: .mono(kick(Kick(low: 50, high: 160, drop: 0.035, hold: 0.03, decay: 0.1, length: 0.3, click: 0.3, drive: 1.6), random: &random))
        case .snare: .mono(snare(random: &random))
        case .clap: .mono(clap(random: &random))
        case .hat: .mono(hat(decay: 0.03, length: 0.12, low: 6000, random: &random))
        case .openHat: .mono(hat(decay: 0.16, length: 0.45, low: 4500, random: &random))
        case .crash: .stereo(crash(random: &random))
        }
    }

    /// A sine falling through `shape`'s pitches, held, then dying; a noise click and a knock an octave up on top, driven
    /// into tanh. Drum and bass's kick falls from 210 Hz, as the reference's hits sweep down from ~300 Hz into the sub.
    private static func kick(_ shape: Kick, random: inout SeededRandom) -> [Float] {
        let count = SoundSignal.count(shape.length)
        let times = SoundSignal.times(count)
        let pitch = vDSP.add(shape.low, vDSP.multiply(shape.high - shape.low, vForce.exp(vDSP.multiply(-1 / shape.drop, times))))
        let held = SoundSignal.decay(vDSP.clip(vDSP.add(-shape.hold, times), to: 0...Double.greatestFiniteMagnitude), shape.decay)
        let body = vDSP.multiply(SoundSignal.sine(following: pitch), held)
        let knock = vDSP.multiply(0.25, vDSP.multiply(SoundSignal.sine(following: vDSP.multiply(2.1, pitch)), SoundSignal.decay(times, 0.012)))
        let snap = vDSP.multiply(shape.click, vDSP.multiply(SoundSignal.peakNormalized(SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()),
                                                                                                       SoundSignal.band(1800, 9000))),
                                                     SoundSignal.decay(times, 0.0025)))
        return shaped(vDSP.add(vDSP.add(body, knock), snap), drive: shape.drive, times: times)
    }

    /// A body sliding 238 → 182 Hz and a ring at 330, under noise from 1.5 to 9.5 kHz with a crack on top.
    private static func snare(random: inout SeededRandom) -> [Float] {
        let count = SoundSignal.count(0.3)
        let times = SoundSignal.times(count)
        let sliding = vDSP.add(182, vDSP.multiply(56, vForce.exp(vDSP.multiply(-1 / 0.02, times))))
        let body = vDSP.add(vDSP.multiply(0.55, vDSP.multiply(SoundSignal.sine(following: sliding), SoundSignal.decay(times, 0.05))),
                            vDSP.multiply(0.2, vDSP.multiply(SoundSignal.sine(330, count: count), SoundSignal.decay(times, 0.03))))
        let wires = vDSP.multiply(SoundSignal.peakNormalized(SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()), SoundSignal.band(1500, 9500))),
                                  vDSP.add(vDSP.multiply(0.75, SoundSignal.decay(times, 0.12)), vDSP.multiply(0.5, SoundSignal.decay(times, 0.02))))
        let crack = vDSP.multiply(0.4, vDSP.multiply(SoundSignal.peakNormalized(SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()),
                                                                                                         SoundSignal.band(4000, 12000))),
                                                     SoundSignal.decay(times, 0.005)))
        return shaped(vDSP.add(vDSP.add(body, wires), crack), drive: 1.3, times: times)
    }

    /// Hands clapping: three bursts 11–12 ms apart, then the room of the fourth, noise from 0.9 to 3.2 kHz.
    private static func clap(random: inout SeededRandom) -> [Float] {
        let count = SoundSignal.count(0.38)
        let times = SoundSignal.times(count)
        let noise = SoundSignal.peakNormalized(SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()), SoundSignal.band(900, 3200)))
        var envelope = [Float](repeating: 0, count: count)
        for (start, decay, level) in [(0.0, 0.0045, Float(0.8)), (0.011, 0.0045, 0.9), (0.023, 0.0045, 0.85), (0.036, 0.14, 1)] {
            let offset = SoundSignal.count(start)
            let burst = vDSP.multiply(level, SoundSignal.decay(Array(times.prefix(count - offset)), decay))
            envelope.replaceSubrange(offset..., with: vDSP.add(envelope[offset...], burst))
        }
        return shaped(vDSP.multiply(noise, envelope), drive: 1.2, times: times)
    }

    /// Six squares at the TR-808's cymbal pitches over `low` Hz, with noise from 1 kHz above it to 15 kHz: both
    /// references hold nothing over 16 kHz, where unfiltered noise put a hiss 30 dB under the loudness.
    private static func hat(decay: Double, length: Double, low: Double, random: inout SeededRandom) -> [Float] {
        let count = SoundSignal.count(length)
        let times = SoundSignal.times(count)
        let band = SoundSignal.band(low + 1000, 15000)
        let air = vDSP.multiply(0.5, SoundSignal.peakNormalized(SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()), band)))
        let sound = vDSP.add(vDSP.multiply(0.6, SoundSignal.filtered(metal(count, scale: 1.6, high: low, random: &random), SoundSignal.lowPass(15000))), air)
        return shaped(vDSP.multiply(sound, SoundSignal.decay(times, decay)), drive: 1, times: times)
    }

    /// A crash: the metal an octave up and noise from 4.5 to 14 kHz, a bright sizzle dying first, in two channels.
    private static func crash(random: inout SeededRandom) -> StereoSound {
        let count = SoundSignal.count(2.2)
        let times = SoundSignal.times(count)
        let body = vDSP.add(vDSP.multiply(0.6, SoundSignal.decay(times, 0.35)), vDSP.multiply(0.4, SoundSignal.decay(times, 1.1)))
        let sizzle = SoundSignal.decay(times, 0.15)
        let side = { (random: inout SeededRandom) -> [Float] in
            let wash = SoundSignal.peakNormalized(SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()), SoundSignal.band(4500, 14000)))
            let top = SoundSignal.peakNormalized(SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()), SoundSignal.band(9000, 15000)))
            let metal = metal(count, scale: 2.4, high: 5000, random: &random)
            return vDSP.add(vDSP.multiply(vDSP.add(vDSP.multiply(0.7, wash), vDSP.multiply(0.35, metal)), body), vDSP.multiply(0.4, vDSP.multiply(top, sizzle)))
        }
        let left = side(&random)
        let right = side(&random)
        let attack = SoundSignal.ramp(times, over: 0.002)
        return finished(StereoSound(left: SoundSignal.fadingTail(vDSP.multiply(left, attack)), right: SoundSignal.fadingTail(vDSP.multiply(right, attack))))
    }

    /// The TR-808's six cymbal squares (205.3–800 Hz) times `scale`, high-passed at `high`, at random phases.
    private static func metal(_ count: Int, scale: Double, high: Double, random: inout SeededRandom) -> [Float] {
        let ones = [Float](repeating: 1, count: count)
        let squares = [205.3, 304.4, 369.6, 522.7, 540, 800].reduce(into: [Float](repeating: 0, count: count)) { sum, frequency in
            let sine = SoundSignal.sine(frequency * scale, count: count, phase: random.uniform(0...(2 * .pi)))
            sum = vDSP.add(sum, vForce.copysign(magnitudes: ones, signs: sine))
        }
        return SoundSignal.peakNormalized(SoundSignal.filtered(squares, SoundSignal.highPass(high) + SoundSignal.highPass(high)))
    }

    /// `signal` driven into tanh, an attack of half a millisecond, its tail faded, peak-normalized.
    private static func shaped(_ signal: [Float], drive: Float, times: [Double]) -> [Float] {
        let driven = drive > 1 ? vForce.tanh(vDSP.multiply(drive, SoundSignal.peakNormalized(signal))) : signal
        return SoundSignal.peakNormalized(SoundSignal.fadingTail(vDSP.multiply(driven, SoundSignal.ramp(times, over: 0.0005))))
    }

    // MARK: - Bass

    /// An 808: a sine and a little of its octave gliding onto `frequency` from `from` (or from 2 semitones up, its boom),
    /// punching in, sustaining, saturated so it reads on small speakers.
    static func sub(_ frequency: Double, from: Double?, length: Double) -> [Float] {
        let count = SoundSignal.count(length)
        let times = SoundSignal.times(count)
        let start = from ?? frequency * pow(2, 2 / 12)
        let glide = vDSP.add(frequency, vDSP.multiply(start - frequency, vForce.exp(vDSP.multiply(-1 / (from == nil ? 0.03 : 0.06), times))))
        let tone = vDSP.add(SoundSignal.sine(following: glide), vDSP.multiply(0.18, SoundSignal.sine(following: vDSP.multiply(2, glide))))
        let punch = vDSP.add(0.75, vDSP.multiply(0.25, SoundSignal.decay(times, 0.15)))
        let envelope = vDSP.multiply(vDSP.multiply(punch, SoundSignal.decay(times, 2.5)), SoundSignal.ramp(times, over: 0.003))
        return release(vForce.tanh(vDSP.multiply(1.3, vDSP.multiply(tone, envelope))), over: 0.025)
    }

    /// House's bass: a saw plucked shut (an open table fading fast into a dark one) over its own sub.
    static func bass(_ frequency: Double, length: Double) -> [Float] {
        let count = SoundSignal.count(length + 0.05)
        let times = SoundSignal.times(count)
        let saw = plucked(frequency, count: count, open: (2500, 0.04), shut: (300, 0.18), phase: 0)
        let sub = vDSP.multiply(0.4, vDSP.multiply(SoundSignal.sine(frequency, count: count), SoundSignal.decay(times, 0.25)))
        return release(vDSP.multiply(vDSP.add(saw, sub), SoundSignal.ramp(times, over: 0.002)), over: 0.015)
    }

    // MARK: - Chords

    /// Two saws a note, 7 cents either side, as a filter closing on a stab: a bright table dying in a sixth of the stab
    /// into a dark one dying over it. Tables, as the pad's are: a sum of sines a partial took 1.8 s for a house film.
    static func stab(_ frequencies: [Double], length: Double, random: inout SeededRandom) -> [Float] {
        let count = SoundSignal.count(length + 0.15)
        let times = SoundSignal.times(count)
        let chord = frequencies.reduce(into: [Float](repeating: 0, count: count)) { sum, frequency in
            for cents in [-7.0, 7] {
                let tuned = frequency * pow(2, cents / 1200)
                sum = vDSP.add(sum, plucked(tuned, count: count, open: (6000, 0.15 * length + 0.02), shut: (650, 0.6 * length), phase: random.unit()))
            }
        }
        return release(vDSP.multiply(chord, SoundSignal.ramp(times, over: 0.002)), over: 0.03)
    }

    /// A saw read from a bright table fading over `open.decay` and a dark one over `shut.decay` (brightness in Hz, as the
    /// pad's), from `phase` (cycles).
    private static func plucked(
        _ frequency: Double, count: Int, open: (brightness: Double, decay: Double), shut: (brightness: Double, decay: Double), phase: Double
    ) -> [Float] {
        let times = SoundSignal.times(count)
        let cycles = vDSP.ramp(withInitialValue: phase, increment: frequency / SoundSignal.sampleRate, count: count)
        let bright = vDSP.multiply(read(wavetable(frequency, brightness: open.brightness), cycles: cycles), SoundSignal.decay(times, open.decay))
        let dark = vDSP.multiply(read(wavetable(frequency, brightness: shut.brightness), cycles: cycles), SoundSignal.decay(times, shut.decay))
        return vDSP.add(bright, dark)
    }

    /// An electric piano: a sine phase-modulated by itself, the index falling from 1.85 to 0.25 as the note goes (its bark
    /// fading to a round tone), and a tine a fourth octave up for a moment.
    static func keys(_ frequencies: [Double], length: Double, random: inout SeededRandom) -> [Float] {
        let count = SoundSignal.count(length + 0.1)
        let times = SoundSignal.times(count)
        let index = vDSP.add(0.25, vDSP.multiply(1.6, vForce.exp(vDSP.multiply(-1 / 0.15, times))))
        let chord = frequencies.reduce(into: [Float](repeating: 0, count: count)) { sum, frequency in
            let tuned = frequency * pow(2, random.uniform(-3...3) / 1200)
            let phase = vDSP.ramp(withInitialValue: random.uniform(0...(2 * .pi)), increment: 2 * .pi * tuned / SoundSignal.sampleRate, count: count)
            let tone = vDSP.doubleToFloat(vForce.sin(vDSP.add(phase, vDSP.multiply(index, vForce.sin(phase)))))
            let tine = vDSP.multiply(0.12, vDSP.multiply(SoundSignal.sine(4 * tuned, count: count), SoundSignal.decay(times, 0.03)))
            sum = vDSP.add(sum, vDSP.add(tone, tine))
        }
        let envelope = vDSP.multiply(SoundSignal.decay(times, max(0.4, 0.7 * length)), SoundSignal.ramp(times, over: 0.002))
        return release(vDSP.multiply(chord, envelope), over: 0.06)
    }

    /// A voice singing "ah" (formants at 730, 1090 and 2440 Hz): sliding from `from` onto `onto` Hz over its first third,
    /// then held with a 5.5 Hz vibrato of a third of a semitone, a breath under it.
    static func vox(from: Double, onto: Double, length: Double, random: inout SeededRandom) -> [Float] {
        let count = SoundSignal.count(length)
        let times = SoundSignal.times(count)
        let slide = vDSP.clip(vDSP.multiply(1 / (0.35 * length), times), to: 0...1)
        // Smoothstep: u²(3 − 2u)
        let eased = vDSP.multiply(vDSP.square(slide), vDSP.add(3, vDSP.multiply(-2, slide)))
        let vibrato = vDSP.multiply(vDSP.clip(vDSP.multiply(1 / (0.4 * length), vDSP.add(-0.4 * length, times)), to: 0...1),
                                    vForce.sin(vDSP.multiply(2 * .pi * 5.5, times)))
        let pitch = vDSP.multiply(vDSP.add(from, vDSP.multiply(onto - from, eased)), vForce.exp(vDSP.multiply(log(2) * 0.3 / 12, vibrato)))
        // Each formant's centre, width and gain
        let formants = [[730, 90, 1], [1090, 110, 0.5], [2440, 160, 0.22]]
        let highest = max(from, onto)
        var voice = [Float](repeating: 0, count: count)
        for harmonic in 1...max(min(14, Int(5000 / highest)), 1) {
            let frequencies = vDSP.multiply(Double(harmonic), pitch)
            let gain = formants.reduce(into: [Double](repeating: 0, count: count)) { sum, formant in
                let distance = vDSP.multiply(1 / formant[1], vDSP.add(-formant[0], frequencies))
                sum = vDSP.add(sum, vDSP.multiply(formant[2], vDSP.divide(1, vDSP.add(1, vDSP.square(distance)))))
            }
            voice = vDSP.add(voice, vDSP.multiply(vDSP.doubleToFloat(gain), SoundSignal.sine(following: frequencies, phase: random.uniform(0...(2 * .pi)))))
        }
        let breath = vDSP.multiply(0.03, SoundSignal.peakNormalized(SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()), SoundSignal.band(1500, 4000))))
        let attack = vDSP.square(SoundSignal.ramp(times, over: 0.05))
        return release(vDSP.multiply(vDSP.add(SoundSignal.peakNormalized(voice), breath), attack), over: 0.25)
    }

    /// `signal` let go over its last `seconds` on a quarter cosine, peak-normalized.
    private static func release(_ signal: [Float], over seconds: Double) -> [Float] {
        let length = min(SoundSignal.count(seconds), signal.count)
        guard length > 0 else { return SoundSignal.peakNormalized(signal) }
        let fade = vForce.cos(vDSP.ramp(withInitialValue: Float(0), increment: .pi / 2 / Float(length), count: length))
        var result = signal
        result.replaceSubrange((signal.count - length)..., with: vDSP.multiply(fade, signal.suffix(length)))
        return SoundSignal.peakNormalized(result)
    }
}
