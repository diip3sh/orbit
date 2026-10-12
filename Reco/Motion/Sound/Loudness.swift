//
//  Loudness.swift
//  Reco
//

import Accelerate

/// Loudness as ITU-R BS.1770-4 measures it, and as ffmpeg's `ebur128` reads it: K-weighted, in 400 ms
/// blocks 100 ms apart, gated at −70 LUFS and 10 LU under the ungated mean; the true peak 4× oversampled.
nonisolated enum Loudness {

    /// The K-weighting's two stages at 48 kHz: a high shelf for the head, then a high-pass.
    private static let kWeighting: SoundSignal.Section = [
        1.53512485958697, -2.69169618940638, 1.19839281085285, -1.69065929318241, 0.73248077421585,
        1, -2, 1, -1.99004745483398, 0.99007225036621
    ]

    /// Mean squares of each 400 ms block, both channels summed.
    private static func blockPowers(of sound: StereoSound) -> [Double] {
        let (block, step) = (SoundSignal.count(0.4), SoundSignal.count(0.1))
        guard sound.count >= block else { return [] }
        // Squares summed a step at a time, then four steps to a block
        let left = stepEnergies(of: sound.left, step: step)
        let right = stepEnergies(of: sound.right, step: step)
        let steps = vDSP.add(left, right)
        return (0...(steps.count - 4)).map { start in vDSP.sum(steps[start..<(start + 4)]) / Double(block) }
    }

    /// The K-weighted energy of each `step` samples of `channel`.
    private static func stepEnergies(of channel: [Float], step: Int) -> [Double] {
        let squares = vDSP.square(SoundSignal.filtered(channel, kWeighting))
        return stride(from: 0, to: squares.count - step + 1, by: step).map { start in Double(vDSP.sum(squares[start..<(start + step)])) }
    }

    /// Integrated loudness in LUFS; −70 or less for silence.
    static func integrated(_ sound: StereoSound) -> Double {
        let loudness = { (power: Double) in -0.691 + 10 * log10(max(power, 1e-20)) }
        let audible = blockPowers(of: sound).filter { loudness($0) > -70 }
        guard !audible.isEmpty else { return -70 }
        let threshold = loudness(audible.reduce(0, +) / Double(audible.count)) - 10
        let gated = audible.filter { loudness($0) > threshold }
        return loudness(gated.reduce(0, +) / Double(gated.count))
    }

    /// The highest sample of either channel 4× oversampled, in dBTP: the peaks between samples a
    /// decoder's output can reach.
    static func truePeak(_ sound: StereoSound) -> Double {
        let peak = max(oversampledPeak(of: sound.left), oversampledPeak(of: sound.right))
        return 20 * log10(max(Double(peak), 1e-10))
    }

    private static func oversampledPeak(of channel: [Float]) -> Float {
        let padding = [Float](repeating: 0, count: phases[0].count)
        let padded = padding + channel + padding
        return phases.map { kernel in vDSP.maximumMagnitude(vDSP.convolve(padded, withKernel: kernel)) }.max() ?? 0
    }

    /// A 48-tap windowed sinc split into its four phases, each a 12-tap interpolator at one of the four
    /// positions between samples (BS.1770-4, Annex 2).
    private static let phases: [[Float]] = {
        let taps = 48
        let filter = (0..<taps).map { tap -> Double in
            let position = (Double(tap) - Double(taps - 1) / 2) / 4
            let sinc = position == 0 ? 1 : sin(.pi * position) / (.pi * position)
            // Blackman
            let share = Double(tap) / Double(taps - 1)
            return sinc * (0.42 - 0.5 * cos(2 * .pi * share) + 0.08 * cos(4 * .pi * share))
        }
        return (0..<4).map { phase in stride(from: phase, to: taps, by: 4).map { Float(filter[$0]) } }
    }()
}
