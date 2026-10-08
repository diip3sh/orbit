//
//  SoundRoom.swift
//  Reco
//

import Accelerate

/// The room every sound is sent to (spec 0013): a synthetic stereo impulse, 2.4 s after an 18 ms predelay,
/// longest in the lows, convolved by FFT. At the cut to black the room stops with the picture: only what's
/// sent from then on rings.
nonisolated enum SoundRoom {

    static let length = 2.4
    static let predelay = 0.018

    /// How much of the room is mixed under the dry sound.
    static let level: Float = 0.32

    /// How long the room takes to stop at the cut to black.
    static let stopFade = 0.006

    /// Seconds to fall 60 dB in each band: 2.2 under 900 Hz, 1.6 to 4 kHz, 0.8 above.
    private static let decays: [(section: SoundSignal.Section, time: Double)] = [
        (SoundSignal.lowPass(900), 2.2), (SoundSignal.band(900, 4000), 1.6), (SoundSignal.highPass(4000), 0.8)
    ]

    /// The room's impulse, the same every time; its energy a channel is 1.
    static func impulse() -> StereoSound {
        var random = SeededRandom(seed: 0x524F_4F4D)
        let count = SoundSignal.count(length)
        let times = SoundSignal.times(count)
        let delay = [Float](repeating: 0, count: SoundSignal.count(predelay))
        let channel = {
            delay + decays.reduce(into: [Float](repeating: 0, count: count)) { sum, band in
                let noise = SoundSignal.filtered(SoundSignal.noise(count, seed: random.next()), band.section)
                // exp(−6.9 t / RT): 60 dB down at RT
                sum = vDSP.add(sum, vDSP.multiply(noise, SoundSignal.decay(times, band.time / 6.9)))
            }
        }
        let impulse = StereoSound(left: channel(), right: channel())
        let energy = ((vDSP.sumOfSquares(impulse.left) + vDSP.sumOfSquares(impulse.right)) / 2).squareRoot()
        return impulse.scaled(1 / energy)
    }

    /// `send` as the room returns it, as long as `send`; what's sent before sample `stop` fades out over
    /// ``stopFade`` from there.
    static func wet(_ send: StereoSound, stop: Int?) -> StereoSound {
        let impulse = impulse()
        guard let left = Convolver(kernel: impulse.left), let right = Convolver(kernel: impulse.right) else { return StereoSound(silence: send.count) }
        guard let stop, stop > 0, stop < send.count else {
            return StereoSound(left: left.convolve(send.left[...], length: send.count), right: right.convolve(send.right[...], length: send.count))
        }
        let fade = min(SoundSignal.count(stopFade), send.count - stop)
        let gate = vDSP.ramp(withInitialValue: Float(1), increment: -1 / Float(max(fade, 1)), count: fade)
        let channel = { (convolver: Convolver, signal: [Float]) -> [Float] in
            var before = convolver.convolve(signal[..<stop], length: stop + fade)
            before.replaceSubrange(stop..., with: vDSP.multiply(gate, before[stop...]))
            let after = convolver.convolve(signal[stop...], length: signal.count - stop)
            return vDSP.add(before + [Float](repeating: 0, count: signal.count - stop - fade), [Float](repeating: 0, count: stop) + after)
        }
        return StereoSound(left: channel(left, send.left), right: channel(right, send.right))
    }
}

/// Overlap-add convolution by DFT with one kernel, its spectrum taken once.
nonisolated private struct Convolver {
    let size: Int
    let block: Int
    let kernel: (real: [Float], imaginary: [Float])
    let forward: vDSP.DiscreteFourierTransform<Float>
    let inverse: vDSP.DiscreteFourierTransform<Float>

    init?(kernel: [Float]) {
        // The smallest power of two that holds the kernel and as long a block again
        size = 1 << Int(log2(Double(2 * kernel.count)).rounded(.up))
        block = size - kernel.count + 1
        guard let forward = try? vDSP.DiscreteFourierTransform(count: size, direction: .forward, transformType: .complexComplex, ofType: Float.self),
              let inverse = try? vDSP.DiscreteFourierTransform(count: size, direction: .inverse, transformType: .complexComplex, ofType: Float.self) else { return nil }
        self.forward = forward
        self.inverse = inverse
        self.kernel = forward.transform(real: kernel + [Float](repeating: 0, count: size - kernel.count), imaginary: [Float](repeating: 0, count: size))
    }

    /// `signal` convolved with the kernel, its first `length` samples.
    func convolve(_ signal: ArraySlice<Float>, length: Int) -> [Float] {
        var output = [Float](repeating: 0, count: length)
        let zeros = [Float](repeating: 0, count: size)
        for start in stride(from: 0, to: min(signal.count, length), by: block) {
            let piece = Array(signal.dropFirst(start).prefix(block))
            let spectrum = forward.transform(real: piece + zeros.prefix(size - piece.count), imaginary: zeros)
            let real = vDSP.subtract(vDSP.multiply(spectrum.real, kernel.real), vDSP.multiply(spectrum.imaginary, kernel.imaginary))
            let imaginary = vDSP.add(vDSP.multiply(spectrum.real, kernel.imaginary), vDSP.multiply(spectrum.imaginary, kernel.real))
            let result = inverse.transform(real: real, imaginary: imaginary).real
            let kept = min(size, length - start)
            output.replaceSubrange(start..<(start + kept), with: vDSP.add(output[start..<(start + kept)], vDSP.multiply(1 / Float(size), result.prefix(kept))))
        }
        return output
    }
}
