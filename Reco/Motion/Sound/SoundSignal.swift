//
//  SoundSignal.swift
//  Reco
//

import Accelerate

/// The arithmetic the score's voices are made with (spec 0013): seeded noise, Butterworth filters,
/// oscillators and envelopes at 48 kHz, each a pass of vDSP over a whole sound, so a film's sound is made
/// in well under a second even in a Debug build, where a loop a sample would take many.
nonisolated enum SoundSignal {

    static let sampleRate = 48_000.0

    /// The samples in `seconds`.
    static func count(_ seconds: Double) -> Int {
        max(Int((seconds * sampleRate).rounded()), 0)
    }

    /// Each sample's time from the first, in seconds.
    static func times(_ count: Int) -> [Double] {
        vDSP.ramp(withInitialValue: 0, increment: 1 / sampleRate, count: count)
    }

    /// A MIDI note's frequency in Hz.
    static func frequency(ofNote note: Double) -> Double {
        440 * pow(2, (note - 69) / 12)
    }

    static func gain(_ decibels: Double) -> Double {
        pow(10, decibels / 20)
    }

    // MARK: - Noise

    /// Gaussian noise of unit variance (Box–Muller), the same for the same seed on every launch.
    static func noise(_ count: Int, seed: UInt64) -> [Float] {
        let pairs = (count + 1) / 2
        var random = SeededRandom(seed: seed)
        var radii = [Float](repeating: 0, count: pairs)
        var angles = [Float](repeating: 0, count: pairs)
        radii.withUnsafeMutableBufferPointer { radii in
            angles.withUnsafeMutableBufferPointer { angles in
                for index in 0..<pairs {
                    radii[index] = Float(random.unit())
                    angles[index] = Float(random.unit())
                }
            }
        }
        let radius = vForce.sqrt(vDSP.multiply(-2, vForce.log(radii)))
        var sines = [Float](repeating: 0, count: pairs)
        var cosines = [Float](repeating: 0, count: pairs)
        vForce.sincos(vDSP.multiply(2 * .pi, angles), sinResult: &sines, cosResult: &cosines)
        return Array((vDSP.multiply(radius, cosines) + vDSP.multiply(radius, sines)).prefix(count))
    }

    // MARK: - Filters

    /// A second-order section's coefficients as vDSP takes them: b0, b1, b2, a1, a2.
    typealias Section = [Double]

    /// Butterworth low- and high-passes of the second order (RBJ's, which are scipy's `butter(2, f)`).
    static func lowPass(_ frequency: Double) -> Section {
        let (cosine, alpha) = shape(frequency, quality: 0.5.squareRoot())
        return normalized([(1 - cosine) / 2, 1 - cosine, (1 - cosine) / 2], [1 + alpha, -2 * cosine, 1 - alpha])
    }

    static func highPass(_ frequency: Double) -> Section {
        let (cosine, alpha) = shape(frequency, quality: 0.5.squareRoot())
        return normalized([(1 + cosine) / 2, -(1 + cosine), (1 + cosine) / 2], [1 + alpha, -2 * cosine, 1 - alpha])
    }

    /// A band from `low` to `high` Hz, as a high-pass then a low-pass: scipy's `butter(2, [low, high])`
    /// within a fraction of a decibel across the band.
    static func band(_ low: Double, _ high: Double) -> Section {
        highPass(low) + lowPass(high)
    }

    /// The first-order Butterworth band-pass from `low` to `high` Hz, scipy's `butter(1, [low, high])`: one
    /// section, its edges prewarped.
    static func narrowBand(_ low: Double, _ high: Double) -> Section {
        let edges = (2 * tan(.pi * low / sampleRate), 2 * tan(.pi * high / sampleRate))
        let (width, center) = (edges.1 - edges.0, edges.0 * edges.1)
        return normalized([2 * width, 0, -2 * width], [4 + 2 * width + center, 2 * center - 8, 4 - 2 * width + center])
    }

    /// `signal` through `sections` (any number of sections, five coefficients each).
    static func filtered(_ signal: [Float], _ sections: Section) -> [Float] {
        guard !signal.isEmpty, var biquad = vDSP.Biquad(
            coefficients: sections, channelCount: 1, sectionCount: vDSP_Length(sections.count / 5), ofType: Float.self
        ) else { return signal }
        return biquad.apply(input: signal)
    }

    /// `signal` through a first-order band-pass whose centre follows `centers` (Hz, a sample each), its width
    /// the centre over `quality`, retuned every 128 samples with its state kept.
    static func swept(_ signal: [Float], centers: [Double], quality: Double) -> [Float] {
        var output = [Float](repeating: 0, count: signal.count)
        var delay = [Float](repeating: 0, count: 4)
        let block = 128
        signal.withUnsafeBufferPointer { input in
            output.withUnsafeMutableBufferPointer { output in
                for start in stride(from: 0, to: signal.count, by: block) {
                    let center = centers[min(start + block / 2, centers.count - 1)]
                    let low = max(center * (1 - 0.5 / quality), 30)
                    let high = min(center * (1 + 0.5 / quality), sampleRate / 2 - 200)
                    guard let setup = vDSP_biquad_CreateSetup(narrowBand(low, high), 1),
                          let source = input.baseAddress, let destination = output.baseAddress else { continue }
                    vDSP_biquad(setup, &delay, source + start, 1, destination + start, 1, vDSP_Length(min(block, signal.count - start)))
                    vDSP_biquad_DestroySetup(setup)
                }
            }
        }
        return output
    }

    private static func shape(_ frequency: Double, quality: Double) -> (cosine: Double, alpha: Double) {
        let omega = 2 * .pi * frequency / sampleRate
        return (cos(omega), sin(omega) / (2 * quality))
    }

    private static func normalized(_ numerator: [Double], _ denominator: [Double]) -> Section {
        let first = denominator[0]
        return numerator.map { $0 / first } + [denominator[1] / first, denominator[2] / first]
    }

    // MARK: - Oscillators and envelopes

    /// sin(2π f t + `phase`) over `count` samples.
    static func sine(_ frequency: Double, count: Int, phase: Double = 0) -> [Float] {
        vDSP.doubleToFloat(vForce.sin(vDSP.ramp(withInitialValue: phase, increment: 2 * .pi * frequency / sampleRate, count: count)))
    }

    /// A sine following `frequencies` (Hz, a sample each) from `phase`.
    static func sine(following frequencies: [Double], phase: Double = 0) -> [Float] {
        vDSP.doubleToFloat(vForce.sin(vDSP.add(phase, cycles(of: frequencies, scale: 2 * .pi))))
    }

    /// The running sum of `frequencies` over the sample rate, times `scale`: a phase in cycles at 1.
    static func cycles(of frequencies: [Double], scale: Double = 1) -> [Double] {
        var sums = [Double](repeating: 0, count: frequencies.count)
        guard !frequencies.isEmpty else { return sums }
        var step = scale / sampleRate
        vDSP_vrsumD(frequencies, 1, &step, &sums, 1, vDSP_Length(frequencies.count))
        return sums
    }

    /// exp(−t/`timeConstant`) over `times`.
    static func decay(_ times: [Double], _ timeConstant: Double) -> [Float] {
        vDSP.doubleToFloat(vForce.exp(vDSP.multiply(-1 / timeConstant, times)))
    }

    /// t/`length`, held at 1 after it: a linear attack.
    static func ramp(_ times: [Double], over length: Double) -> [Float] {
        vDSP.doubleToFloat(vDSP.clip(vDSP.multiply(1 / length, times), to: 0...1))
    }

    /// `signal` scaled so its largest sample is 1.
    static func peakNormalized(_ signal: [Float]) -> [Float] {
        let peak = vDSP.maximumMagnitude(signal)
        return peak > 0 ? vDSP.multiply(1 / peak, signal) : signal
    }

    /// The last 4 ms faded out, so a sound cut short doesn't click.
    static func fadingTail(_ signal: [Float]) -> [Float] {
        let length = min(count(0.004), signal.count)
        guard length > 0 else { return signal }
        var result = signal
        let fade = vDSP.ramp(withInitialValue: Float(1), increment: -1 / Float(length), count: length)
        result.replaceSubrange((signal.count - length)..., with: vDSP.multiply(fade, signal.suffix(length)))
        return result
    }
}

/// Two channels of sound at ``SoundSignal/sampleRate``.
nonisolated struct StereoSound: Equatable, Sendable {
    var left: [Float]
    var right: [Float]

    init(left: [Float], right: [Float]) {
        self.left = left
        self.right = right
    }

    init(silence count: Int) {
        left = [Float](repeating: 0, count: count)
        right = left
    }

    var count: Int {
        left.count
    }

    /// The largest sample of either channel.
    var peak: Float {
        max(vDSP.maximumMagnitude(left), vDSP.maximumMagnitude(right))
    }

    /// The root mean square of both channels together.
    var rms: Float {
        ((vDSP.sumOfSquares(left) + vDSP.sumOfSquares(right)) / Float(max(2 * count, 1))).squareRoot()
    }

    func scaled(_ factor: Float) -> StereoSound {
        StereoSound(left: vDSP.multiply(factor, left), right: vDSP.multiply(factor, right))
    }

    func applying(_ envelope: [Float]) -> StereoSound {
        StereoSound(left: vDSP.multiply(envelope, left), right: vDSP.multiply(envelope, right))
    }

    /// Adds `sound` times `gains` (left, right) from sample `offset`; what falls outside is left out.
    mutating func add(_ sound: (left: [Float], right: [Float]), gains: (left: Float, right: Float), at offset: Int) {
        let skipped = max(-offset, 0)
        let length = min(sound.left.count - skipped, count - max(offset, 0))
        guard length > 0 else { return }
        let start = max(offset, 0)
        Self.add(sound.left, from: skipped, times: gains.left, into: &left, at: start..<(start + length))
        Self.add(sound.right, from: skipped, times: gains.right, into: &right, at: start..<(start + length))
    }

    private static func add(_ source: [Float], from first: Int, times gain: Float, into channel: inout [Float], at range: Range<Int>) {
        var gain = gain
        source.withUnsafeBufferPointer { source in
            channel.withUnsafeMutableBufferPointer { channel in
                guard let input = source.baseAddress, let output = channel.baseAddress else { return }
                vDSP_vsma(input + first, 1, &gain, output + range.lowerBound, 1, output + range.lowerBound, 1, vDSP_Length(range.count))
            }
        }
    }
}

/// SplitMix64: the same numbers for the same seed on every Mac and launch, unlike the system's generator.
nonisolated struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    /// A share in (0, 1].
    mutating func unit() -> Double {
        Double((next() >> 11) + 1) / Double(1 << 53)
    }

    mutating func uniform(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit()
    }
}
