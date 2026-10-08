//
//  SoundVoices+Score.swift
//  Reco
//

import Accelerate

/// The score's own voices: a chord as a pad and the air under the shots.
nonisolated extension SoundVoices {

    /// Each pad voice reads one band-limited cycle from a table: summing a sine per harmonic of every
    /// voice for a minute of score would take ~700 M sines.
    static let tableLength = 2048

    /// `chord` as a pad, ringing on for its release: three saws a note, detuned −7, 0 and +7 cents and
    /// spread left, centre and right, each harmonic k at e^(−k·f/brightness)/k, with a slow vibrato and a
    /// bass sine at 35 % of the chord's RMS. Its RMS before the envelope is 1.
    static func pad(_ chord: SoundCueSheet.Chord, seed: UInt64) -> StereoSound {
        var random = SeededRandom(seed: seed)
        let hold = chord.end - chord.start
        let count = SoundSignal.count(hold + chord.release)
        let times = SoundSignal.times(count)
        var pad = StereoSound(silence: count)
        for note in chord.notes {
            let frequency = SoundSignal.frequency(ofNote: Double(note))
            let table = wavetable(frequency, brightness: chord.brightness)
            for (cents, side) in [(-7.0, -0.75), (0, 0), (7, 0.75)] {
                let vibrato = (rate: random.uniform(0.12...0.3), phase: random.uniform(0...6.3))
                let wobble = vForce.sin(vDSP.add(vibrato.phase, vDSP.multiply(2 * .pi * vibrato.rate, times)))
                let frequencies = vDSP.multiply(frequency * pow(2, cents / 1200), vDSP.add(1, vDSP.multiply(0.0012, wobble)))
                let voice = read(table, cycles: vDSP.add(random.unit(), SoundSignal.cycles(of: frequencies)))
                let angle = Float((side + 1) * .pi / 4)
                pad.add((voice, voice), gains: (cos(angle), sin(angle)), at: 0)
            }
        }
        if let bass = chord.bass {
            let frequency = SoundSignal.frequency(ofNote: Double(bass))
            let low = vDSP.add(SoundSignal.sine(frequency, count: count), vDSP.multiply(0.4, SoundSignal.sine(2 * frequency, count: count)))
            let level = 0.35 * pad.rms / max(StereoSound(left: low, right: low).rms, .leastNonzeroMagnitude)
            pad.add((low, low), gains: (level, level), at: 0)
        }
        let rms = pad.rms
        return pad.scaled(rms > 0 ? 1 / rms : 0).applying(envelope(of: chord, times: times))
    }

    /// One cycle of a saw whose harmonic k is e^(−k·f/brightness)/k, up to 16 of them and none past 7 kHz,
    /// with its first sample again at the end for interpolation.
    private static func wavetable(_ frequency: Double, brightness: Double) -> [Float] {
        let phases = vDSP.ramp(withInitialValue: 0.0, increment: 2 * .pi / Double(tableLength), count: tableLength + 1)
        let harmonics = max(min(16, Int(7000 / frequency)), 1)
        return vDSP.doubleToFloat((1...harmonics).reduce(into: [Double](repeating: 0, count: tableLength + 1)) { table, harmonic in
            let order = Double(harmonic)
            table = vDSP.add(table, vDSP.multiply(exp(-order * frequency / brightness) / order, vForce.sin(vDSP.multiply(order, phases))))
        })
    }

    /// `table` read at `cycles` (a phase in cycles a sample), linearly interpolated.
    private static func read(_ table: [Float], cycles: [Double]) -> [Float] {
        var fractions = [Double](repeating: 0, count: cycles.count)
        vDSP_vfracD(cycles, 1, &fractions, 1, vDSP_Length(cycles.count))
        let positions = vDSP.doubleToFloat(fractions)
        var output = [Float](repeating: 0, count: cycles.count)
        var scale = Float(tableLength)
        var offset = Float(0)
        vDSP_vtabi(positions, 1, &scale, &offset, table, vDSP_Length(table.count), &output, 1, vDSP_Length(cycles.count))
        return output
    }

    /// In over its attack (squared), moving by its swell to its end, then out on a quarter cosine.
    private static func envelope(of chord: SoundCueSheet.Chord, times: [Double]) -> [Float] {
        let hold = max(chord.end - chord.start, 1e-4)
        let attack = vDSP.square(vDSP.clip(vDSP.multiply(1 / max(chord.attack, 1e-4), times), to: 0...1))
        let swell = vForce.pow(bases: [Double](repeating: 10, count: times.count), exponents: vDSP.multiply(chord.swell / 20, vDSP.clip(vDSP.multiply(1 / hold, times), to: 0...1)))
        let release = vForce.cos(vDSP.multiply(.pi / 2, vDSP.clip(vDSP.multiply(1 / max(chord.release, 1e-4), vDSP.add(-hold, times)), to: 0...1)))
        return vDSP.doubleToFloat(vDSP.multiply(vDSP.multiply(attack, swell), release))
    }

    /// Noise from 160 Hz to 2.4 kHz, breathing 25 % every 11 s, in over 1.2 s. Its RMS is 1.
    static func air(_ air: SoundCueSheet.Air, seed: UInt64) -> StereoSound {
        var random = SeededRandom(seed: seed)
        let count = SoundSignal.count(air.end - air.start)
        let band = SoundSignal.highPass(160) + SoundSignal.lowPass(2400)
        var noise = StereoSound(left: SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()), band),
                                right: SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()), band))
        noise = noise.scaled(1 / max(noise.rms, .leastNonzeroMagnitude))
        let times = SoundSignal.times(count)
        let breathing = vDSP.doubleToFloat(vDSP.add(1, vDSP.multiply(0.25, vForce.sin(vDSP.multiply(2 * .pi * 0.09, times)))))
        noise = noise.applying(vDSP.multiply(breathing, SoundSignal.ramp(times, over: 1.2)))
        return StereoSound(left: SoundSignal.fadingTail(noise.left), right: SoundSignal.fadingTail(noise.right))
    }
}
