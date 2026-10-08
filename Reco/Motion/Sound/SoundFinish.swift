//
//  SoundFinish.swift
//  Reco
//

import Accelerate

/// The last stage of the score (spec 0013), as the hand-made Supabase film was mastered: rumble under 32 Hz
/// cut, a 0.7 s fade at the end, a soft clip, then −16 LUFS integrated with true peaks at or under −1.5 dBTP.
/// The film the user heard measured −16.0 LUFS and −1.9 dBTP.
nonisolated enum SoundFinish {

    static let loudness = -16.0
    static let ceiling = -1.5
    static let fadeOut = 0.7

    /// The soft clip's drive: tanh at 1.2 times the peak, to −1 dBFS.
    private static let drive: Float = 1.2

    /// Where the limiter's knee starts, as a share of its ceiling, and how far under the true-peak ceiling
    /// it holds samples, for the peaks between them.
    private static let knee: Float = 0.6
    private static let headroom = 0.5

    static func finished(_ mix: StereoSound) -> StereoSound {
        guard mix.peak > 0 else { return mix }
        let rumble = SoundSignal.highPass(32)
        var sound = StereoSound(left: SoundSignal.filtered(mix.left, rumble), right: SoundSignal.filtered(mix.right, rumble))
        sound = sound.applying(fade(count: sound.count))
        // The soft clip: tanh(1.2 x / peak) / tanh(1.2), at −1 dBFS
        let scale = drive / sound.peak
        let level = Float(SoundSignal.gain(-1)) / tanh(drive)
        sound = StereoSound(left: vDSP.multiply(level, vForce.tanh(vDSP.multiply(scale, sound.left))),
                            right: vDSP.multiply(level, vForce.tanh(vDSP.multiply(scale, sound.right))))
        return normalized(sound)
    }

    /// `sound` at ``loudness``, peaks held under ``ceiling``: limited where the gain lifts them over it,
    /// lowered if still over.
    static func normalized(_ sound: StereoSound) -> StereoSound {
        var result = sound
        var gain = 1.0
        for _ in 0..<3 {
            gain *= SoundSignal.gain(loudness - Loudness.integrated(result))
            result = limited(sound.scaled(Float(gain)))
        }
        let over = Loudness.truePeak(result) - ceiling
        return over > 0 ? result.scaled(Float(SoundSignal.gain(-over))) : result
    }

    /// Samples over the knee bent into ``ceiling`` less ``headroom``; under it, untouched.
    private static func limited(_ sound: StereoSound) -> StereoSound {
        let top = Float(SoundSignal.gain(ceiling - headroom))
        let (start, range) = (knee * top, (1 - knee) * top)
        guard sound.peak > start else { return sound }
        let bend = { (channel: [Float]) -> [Float] in
            let magnitude = vDSP.absolute(channel)
            let over = vDSP.clip(vDSP.add(-start, magnitude), to: 0...Float.greatestFiniteMagnitude)
            let bent = vDSP.add(vDSP.subtract(magnitude, over), vDSP.multiply(range, vForce.tanh(vDSP.multiply(1 / range, over))))
            return vForce.copysign(magnitudes: bent, signs: channel)
        }
        return StereoSound(left: bend(sound.left), right: bend(sound.right))
    }

    /// 1, then a quarter cosine down to 0 over the last ``fadeOut``.
    private static func fade(count: Int) -> [Float] {
        let length = min(SoundSignal.count(fadeOut), count)
        let tail = vForce.cos(vDSP.ramp(withInitialValue: Float(0), increment: .pi / 2 / Float(length), count: length))
        return [Float](repeating: 1, count: count - length) + tail
    }
}
