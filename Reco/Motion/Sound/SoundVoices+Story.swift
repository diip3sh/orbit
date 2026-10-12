//
//  SoundVoices+Story.swift
//  Reco
//

import Accelerate

/// A story film's own transition sound (spec 0015).
nonisolated extension SoundVoices {

    /// A dither seam: the frame breaking into dots and resolving as tiny square blips, a few each step the seam takes
    /// (``SeamExpansion/Transition/ditherSteps`` a second), their pitches scattered over the sixth and seventh octaves,
    /// swelling to the seam's middle and thinning out, each somewhere across the stereo field, band-passed so they read as
    /// data, not beeps.
    static func bits(length: Double, random: inout SeededRandom) -> StereoSound {
        let count = SoundSignal.count(length + bitsLongest)
        var (left, right) = ([Float](repeating: 0, count: count), [Float](repeating: 0, count: count))
        let rate = SeamExpansion.Transition.ditherSteps
        let steps = max(Int((length * rate).rounded()), 1)
        for step in 0..<steps {
            let swell = sin(.pi * (Double(step) + 0.5) / Double(steps))
            for _ in 0..<Int((1 + bitsMost * swell).rounded()) {
                let start = SoundSignal.count((Double(step) + random.unit()) / rate)
                let size = SoundSignal.count(random.uniform(bitsShortest...bitsLongest))
                guard start + size <= count else { continue }
                let tone = SoundSignal.sine(SoundSignal.frequency(ofNote: random.uniform(bitsNotes)), count: size, phase: random.uniform(0...(2 * .pi)))
                let square = vForce.copysign(magnitudes: [Float](repeating: 1, count: size), signs: tone)
                let blip = vDSP.multiply(Float(0.35 + 0.65 * swell), vDSP.multiply(square, SoundSignal.decay(SoundSignal.times(size), Double(size) / SoundSignal.sampleRate / 3)))
                // Equal power across the field
                let angle = (random.uniform(-bitsSpread...bitsSpread) + 1) * .pi / 4
                left.replaceSubrange(start..<(start + size), with: vDSP.add(left[start..<(start + size)], vDSP.multiply(Float(cos(angle)), blip)))
                right.replaceSubrange(start..<(start + size), with: vDSP.add(right[start..<(start + size)], vDSP.multiply(Float(sin(angle)), blip)))
            }
        }
        let band = SoundSignal.band(1200, 9000)
        let sound = StereoSound(left: SoundSignal.filtered(left, band), right: SoundSignal.filtered(right, band))
        return sound.scaled(1 / max(sound.peak, 1e-6))
    }

    /// Up to this many more blips a step at the seam's middle; how long each is; their pitches (MIDI, C6–G♯7); how far
    /// across the field they sit.
    static let bitsMost = 4.0
    static let bitsShortest = 0.012
    static let bitsLongest = 0.03
    static let bitsNotes = 84.0...104.0
    static let bitsSpread = 0.7
}
