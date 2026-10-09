//
//  SoundVoices.swift
//  Reco
//

import Accelerate

/// The score's voices, generated, never recorded (spec 0013): the hand-made Supabase film's (`score.py`,
/// round 6) in Swift. Library recordings brought noise and a character that matched nothing else in its mix.
/// Each sound is peak-normalized; its cue sets its level.
nonisolated enum SoundVoices {

    /// A cue's sound: one channel to pan, or two.
    nonisolated enum Sound {
        case mono([Float])
        case stereo(StereoSound)
    }

    static func sound(of cue: SoundCue) -> Sound {
        var random = SeededRandom(seed: Patch(cue)?.seed ?? cue.seed)
        let pitch = SoundSignal.frequency(ofNote:)
        switch cue.voice {
        case .glass(let note, let length, let brightness): return .mono(glass(pitch(note), length: length, brightness: brightness, random: &random))
        case .felt(let note, let length): return .mono(felt(pitch(note), length: length, random: &random))
        case .blip(let note, let length): return .mono(blip(pitch(note), length: length))
        case .thump(let high, let low, let length, let decay): return .mono(thump(high: high, low: low, length: length, decay: decay))
        case .key(let key): return .mono(self.key(key, random: &random))
        case .swish(let length): return .stereo(swish(length: length, random: &random))
        case .whoosh: return .stereo(whoosh(random: &random))
        case .riser(let length, let low, let high, let power): return .stereo(riser(length: length, low: low, high: high, power: power, random: &random))
        case .drum, .sub, .bass, .stab, .keys, .vox: return beat(cue.voice, random: &random)
        case .bits(let length): return .stereo(bits(length: length, random: &random))
        }
    }

    /// A beat score's sound as a sampler holds it (spec 0015): the same note or drum the same every time it's played,
    /// a drum in one of ``drumTakes`` takes, so a render makes each once. Making every hit afresh took 0.9 s of a 45 s
    /// house film's 1.4 in Debug.
    nonisolated struct Patch: Hashable, Sendable {
        let voice: SoundCue.Voice
        let take: UInt64

        static let drumTakes: UInt64 = 4

        /// `cue`'s patch; `nil` for the score's and effects' own sounds, each drawn afresh from its seed.
        init?(_ cue: SoundCue) {
            switch cue.voice {
            case .drum: (voice, take) = (cue.voice, cue.seed % Self.drumTakes)
            case .sub, .bass, .stab, .keys, .vox: (voice, take) = (cue.voice, 0)
            default: return nil
            }
        }

        var seed: UInt64 {
            0x5A3D_1E00 &+ take
        }
    }

    // MARK: - Tones

    /// An overtone: its frequency's ratio to the note's, its amplitude, and its decay's time constant.
    struct Partial {
        let ratio: Double
        let amplitude: Double
        let decay: Double

        init(_ ratio: Double, _ amplitude: Double, _ decay: Double) {
            (self.ratio, self.amplitude, self.decay) = (ratio, amplitude, decay)
        }
    }

    /// Partials with random phases, each decaying on its own time constant.
    static func partials(_ frequency: Double, _ partials: [Partial], times: [Double], random: inout SeededRandom) -> [Float] {
        partials.reduce(into: [Float](repeating: 0, count: times.count)) { sum, partial in
            let tone = SoundSignal.sine(frequency * partial.ratio, count: times.count, phase: random.uniform(0...(2 * .pi)))
            sum = vDSP.add(sum, vDSP.multiply(Float(partial.amplitude), vDSP.multiply(tone, SoundSignal.decay(times, partial.decay))))
        }
    }

    static func glass(_ frequency: Double, length: Double, brightness: Double, random: inout SeededRandom) -> [Float] {
        let times = SoundSignal.times(SoundSignal.count(length))
        let ring = partials(frequency, [
            Partial(1, 1, 0.45 * length), Partial(2, 0.32, 0.25 * length), Partial(3.01, 0.14 * brightness, 0.14 * length),
            Partial(4.23, 0.07 * brightness, 0.08 * length), Partial(5.41, 0.04 * brightness, 0.05 * length)
        ], times: times, random: &random)
        return SoundSignal.peakNormalized(vDSP.multiply(ring, SoundSignal.ramp(times, over: 0.0015)))
    }

    static func felt(_ frequency: Double, length: Double, random: inout SeededRandom) -> [Float] {
        let times = SoundSignal.times(SoundSignal.count(length))
        let overtones = [Partial(1, 1, 0.32 * length), Partial(2, 0.28, 0.16 * length), Partial(3, 0.08, 0.09 * length), Partial(4.02, 0.03, 0.06 * length)]
        let note = partials(frequency, overtones, times: times, random: &random)
        // A 4 ms attack: the hammer's felt, no click
        let attack = vDSP.add(1, vDSP.multiply(-1, SoundSignal.decay(times, 0.004)))
        return SoundSignal.peakNormalized(vDSP.multiply(note, attack))
    }

    static func blip(_ frequency: Double, length: Double) -> [Float] {
        let times = SoundSignal.times(SoundSignal.count(length))
        let sliding = vDSP.multiply(frequency, vDSP.add(1, vDSP.multiply(-0.1, vForce.exp(vDSP.multiply(-1 / 0.01, times)))))
        let tone = vDSP.add(SoundSignal.sine(following: sliding), vDSP.multiply(0.22, SoundSignal.sine(following: vDSP.multiply(2, sliding))))
        return SoundSignal.peakNormalized(vDSP.multiply(vDSP.multiply(tone, SoundSignal.ramp(times, over: 0.003)), SoundSignal.decay(times, 0.085)))
    }

    static func thump(high: Double, low: Double, length: Double, decay: Double) -> [Float] {
        let times = SoundSignal.times(SoundSignal.count(length))
        let sliding = vDSP.add(low, vDSP.multiply(high - low, vForce.exp(vDSP.multiply(-1 / 0.045, times))))
        let tone = vDSP.add(SoundSignal.sine(following: sliding), vDSP.multiply(0.35, SoundSignal.sine(following: vDSP.multiply(2, sliding))))
        return SoundSignal.peakNormalized(vDSP.multiply(vDSP.multiply(tone, SoundSignal.decay(times, decay)), SoundSignal.ramp(times, over: 0.002)))
    }

    // MARK: - Keys

    /// A key's body pitch and how long it rings: a space bar is lower and longer.
    private static func body(of key: SoundCue.Key, random: inout SeededRandom) -> (pitch: Double, decay: Double) {
        switch key {
        case .letter: (random.uniform(195...245), 0.016)
        case .space: (128, 0.032)
        case .arrow: (random.uniform(220...240), 0.014)
        case .enter: (150, 0.03)
        }
    }

    static func key(_ key: SoundCue.Key, random: inout SeededRandom) -> [Float] {
        let count = SoundSignal.count(0.18)
        let times = SoundSignal.times(count)
        let (pitch, ring) = body(of: key, random: &random)
        let seeds = (click: random.next(), thud: random.next(), release: random.next())
        let shaped = { (signal: [Float], decay: Double) in SoundSignal.peakNormalized(vDSP.multiply(signal, SoundSignal.decay(times, decay))) }
        let click = shaped(SoundSignal.filtered(SoundSignal.noise(count, seed: seeds.click), SoundSignal.band(2500, 8500)), 0.0028)
        let tick = shaped(SoundSignal.sine(random.uniform(1250...1700), count: count), 0.005)
        let sliding = vDSP.multiply(pitch, vDSP.add(1, vDSP.multiply(0.3, vForce.exp(vDSP.multiply(-1 / 0.007, times)))))
        let tone = shaped(SoundSignal.sine(following: sliding), ring)
        let thud = shaped(SoundSignal.filtered(SoundSignal.noise(count, seed: seeds.thud), SoundSignal.lowPass(700)), 0.012)
        // The key coming back up 75–100 ms later
        let lifted = min(SoundSignal.count(random.uniform(0.075...0.1)), count)
        let snap = shaped(SoundSignal.filtered(SoundSignal.noise(count, seed: seeds.release), SoundSignal.band(3000, 9000)), 0.002).prefix(count - lifted)
        let release = [Float](repeating: 0, count: lifted) + snap
        let rattle: Float = key == .space || key == .enter ? 0.25 : 0
        let parts = [(click, 0.5), (tick, 0.16), (tone, 0.75), (thud, 0.3 + rattle), (release, 0.22)] as [([Float], Float)]
        return SoundSignal.peakNormalized(parts.reduce(into: [Float](repeating: 0, count: count)) { $0 = vDSP.add($0, vDSP.multiply($1.1, $1.0)) })
    }

    // MARK: - Air

    /// Two channels of noise through `section`.
    static func stereoNoise(_ count: Int, _ section: SoundSignal.Section, random: inout SeededRandom) -> StereoSound {
        StereoSound(left: SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()), section),
                    right: SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()), section))
    }

    /// Two channels of noise through a band-pass following `centers`.
    private static func sweptNoise(_ centers: [Double], quality: Double, random: inout SeededRandom) -> StereoSound {
        StereoSound(left: SoundSignal.swept(SoundSignal.noise(centers.count, seed: random.next()), centers: centers, quality: quality),
                    right: SoundSignal.swept(SoundSignal.noise(centers.count, seed: random.next()), centers: centers, quality: quality))
    }

    /// `count` frequencies from `start` to `end` in equal ratios.
    private static func glide(_ start: Double, _ end: Double, count: Int) -> [Double] {
        guard count > 1 else { return [start] }
        return vForce.exp(vDSP.ramp(withInitialValue: log(start), increment: log(end / start) / Double(count - 1), count: count))
    }

    /// `times` over `length`, to `power`: a rise that's slow, then steep.
    private static func rising(_ times: [Double], over length: Double, power: Double) -> [Float] {
        vDSP.doubleToFloat(vForce.pow(bases: vDSP.multiply(1 / length, times), exponents: [Double](repeating: power, count: times.count)))
    }

    static func swish(length: Double, random: inout SeededRandom) -> StereoSound {
        let count = SoundSignal.count(length)
        let air = stereoNoise(count, SoundSignal.band(900, 7000), random: &random).applying(rising(SoundSignal.times(count), over: length, power: 3))
        return finished(StereoSound(left: SoundSignal.fadingTail(air.left), right: SoundSignal.fadingTail(air.right)))
    }

    static func riser(length: Double, low: Double, high: Double, power: Double, random: inout SeededRandom) -> StereoSound {
        let count = SoundSignal.count(length)
        let air = sweptNoise(glide(low, high, count: count), quality: 1.6, random: &random).applying(rising(SoundSignal.times(count), over: length, power: power))
        return finished(StereoSound(left: SoundSignal.fadingTail(air.left), right: SoundSignal.fadingTail(air.right)))
    }

    /// A whip: swept up from 320 Hz to 3.2 kHz as the camera speeds up, down to 900 Hz as it lands, panned
    /// across with it, a low body under it.
    static func whoosh(random: inout SeededRandom) -> StereoSound {
        let rise = SoundSignal.count(SoundCue.whooshRise)
        let count = rise + SoundSignal.count(SoundCue.whooshFall)
        let times = SoundSignal.times(count)
        let centers = glide(320, 3200, count: rise) + glide(3200, 900, count: count - rise)
        let climb = rising(Array(times.prefix(rise)), over: SoundCue.whooshRise, power: 2.6)
        let fall = SoundSignal.decay(vDSP.add(-SoundCue.whooshRise, Array(times.suffix(count - rise))), 0.055)
        let envelope = climb + fall
        let rush = sweptNoise(centers, quality: 1.1, random: &random).applying(envelope)
        let body = finished(stereoNoise(count, SoundSignal.lowPass(400), random: &random).applying(envelope)).scaled(0.35)
        let sound = finished(StereoSound(left: vDSP.add(rush.left, body.left), right: vDSP.add(rush.right, body.right)))
        let pan = vDSP.ramp(in: Float(-0.35)...0.35, count: count)
        return StereoSound(left: vDSP.multiply(sound.left, vDSP.add(1, vDSP.multiply(-1, pan))), right: vDSP.multiply(sound.right, vDSP.add(1, pan)))
    }

    /// `sound` scaled so its largest sample on either side is 1.
    static func finished(_ sound: StereoSound) -> StereoSound {
        let peak = sound.peak
        return peak > 0 ? sound.scaled(1 / peak) : sound
    }
}
