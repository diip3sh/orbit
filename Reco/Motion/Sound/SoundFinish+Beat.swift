//
//  SoundFinish+Beat.swift
//  Reco
//

import Accelerate

/// A beat score's master (spec 0015): drums peak 18–20 dB over their loudness, and both references sit at 13–13.5 dB
/// (Lovable −15.8 LUFS under a clipped +0.4 dBFS, the Spotify Jam −14.3), so the peaks are held down by a limiter that
/// turns the gain down ahead of each and lets it back over 80 ms. Bending samples as spec 0013's finish does would
/// distort every kick at that depth.
nonisolated extension SoundFinish {

    /// How far ahead the limiter sees a peak, and how fast it lets go.
    static let lookahead = 0.0015
    static let limiterRelease = 0.08

    /// `mix` at `finish`'s loudness, its true peaks at or under its ceiling.
    static func finished(_ mix: StereoSound, to finish: SoundCueSheet.Finish) -> StereoSound {
        guard mix.peak > 0 else { return mix }
        let rumble = SoundSignal.highPass(30)
        let fade = fade(count: mix.count)
        let sound = StereoSound(left: SoundSignal.filtered(mix.left, rumble), right: SoundSignal.filtered(mix.right, rumble)).applying(fade)
        // Samples held half a decibel under the ceiling: the peaks between them reach a little higher
        let top = Float(SoundSignal.gain(finish.ceiling - 0.5))
        var gain = 1.0
        var result = sound
        for _ in 0..<3 {
            gain *= SoundSignal.gain(finish.loudness - Loudness.integrated(result))
            result = limited(sound.scaled(Float(gain)), to: top)
        }
        let over = Loudness.truePeak(result) - finish.ceiling
        return over > 0 ? result.scaled(Float(SoundSignal.gain(-over))) : result
    }

    /// `sound` with its gain turned down ahead of every sample over `top`, block by block, and let back up over
    /// ``limiterRelease``; the gain between blocks is the lower of theirs, so no sample passes `top`. Only the release
    /// is a loop, a step a block; the rest is vDSP (a loop a sample took 0.7 s of a 45 s groove in Debug).
    private static func limited(_ sound: StereoSound, to top: Float) -> StereoSound {
        let block = 32
        let blocks = sound.count / block
        guard blocks > 1 else { return sound }
        // Each block's peak: a sliding maximum, read every block
        let magnitude = vDSP.maximum(vDSP.absolute(sound.left), vDSP.absolute(sound.right)) + [Float](repeating: 0, count: block)
        let peaks = slidingMaximum(magnitude, window: block, every: block, count: blocks)
        let need = vDSP.minimum(vDSP.divide(top, vDSP.clip(peaks, to: top...Float.greatestFiniteMagnitude)), [Float](repeating: 1, count: blocks))
        // Down ahead of the peak (the least need over the blocks to come), then back up on a one-pole curve
        let ahead = max(Int((lookahead * SoundSignal.sampleRate / Double(block)).rounded(.up)), 1) + 1
        let target = vDSP.multiply(-1, slidingMaximum(vDSP.multiply(-1, need) + [Float](repeating: -1, count: ahead), window: ahead, every: 1, count: blocks))
        let recovery = Float(1 - exp(-Double(block) / (limiterRelease * SoundSignal.sampleRate)))
        var gains = [Float](repeating: 1, count: blocks + 1)
        var level: Float = 1
        for index in 0..<blocks {
            level = min(target[index], level + (1 - level) * recovery)
            gains[index] = level
        }
        // A block's edges take the lower of it and its neighbour's gain, ramped across it
        let edges = vDSP.minimum(gains, [1] + gains.dropLast())
        var positions = vDSP.ramp(withInitialValue: Float(0), increment: 1 / Float(block), count: sound.count)
        positions = vDSP.clip(positions, to: 0...Float(blocks) - 0.0001)
        var envelope = [Float](repeating: 1, count: sound.count)
        vDSP_vlint(edges, positions, 1, &envelope, 1, vDSP_Length(sound.count), vDSP_Length(edges.count))
        return sound.applying(envelope)
    }

    /// The maximum of each `window` of `values` from every `every`-th, `count` of them.
    private static func slidingMaximum(_ values: [Float], window: Int, every: Int, count: Int) -> [Float] {
        var sliding = [Float](repeating: 0, count: values.count - window + 1)
        vDSP_vswmax(values, 1, &sliding, 1, vDSP_Length(sliding.count), vDSP_Length(window))
        guard every > 1 else { return Array(sliding.prefix(count)) }
        return (0..<count).map { sliding[$0 * every] }
    }
}
