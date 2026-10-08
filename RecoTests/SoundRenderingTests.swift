//
//  SoundRenderingTests.swift
//  RecoTests
//

import Accelerate
import AVFoundation
import Testing
@testable import Reco

/// The score's sound (spec 0013): measured as BS.1770 measures it, the same every time, mastered to
/// −16 LUFS under −1.5 dBTP, and in an export on the frames it marks.
struct SoundRenderingTests {

    /// A stereo sine of `amplitude` at `frequency` Hz, `seconds` long.
    private func sine(_ frequency: Double, amplitude: Float, seconds: Double, phase: Double = 0) -> StereoSound {
        let tone = vDSP.multiply(amplitude, SoundSignal.sine(frequency, count: SoundSignal.count(seconds), phase: phase))
        return StereoSound(left: tone, right: tone)
    }

    /// EBU Tech 3341's first case: a 1 kHz sine at −23 dBFS in both channels reads −23.0 LUFS, as ffmpeg's
    /// `ebur128` read the hand-made Supabase score at −15.4 LUFS where this read it the same.
    @Test func measuresLoudnessAsBS1770Does() {
        #expect(abs(Loudness.integrated(sine(1000, amplitude: Float(SoundSignal.gain(-23)), seconds: 10)) + 23) < 0.1)
        #expect(Loudness.integrated(StereoSound(silence: SoundSignal.count(2))) <= -70)
    }

    /// A sine at a quarter of the sample rate, 45° off its samples, peaks 3 dB above them.
    @Test func findsThePeakBetweenSamples() {
        let tone = sine(SoundSignal.sampleRate / 4, amplitude: 0.5, seconds: 1, phase: .pi / 4)
        #expect(abs(20 * log10(Double(tone.peak)) - 20 * log10(0.5 * 0.5.squareRoot())) < 0.01)
        #expect(abs(Loudness.truePeak(tone) - 20 * log10(0.5)) < 0.3)
    }

    /// A short sheet: a pad, the air, a hit, a key, a whip and a felt note.
    private let sheet = SoundCueSheet(
        length: 4,
        chords: [SoundCueSheet.Chord(notes: [50, 57, 61, 64, 66], bass: 38, start: 0, end: 2, level: -30),
                 SoundCueSheet.Chord(notes: [47, 54, 57, 62, 64], bass: 35, start: 2, end: 4, level: -28)],
        air: SoundCueSheet.Air(start: 0, end: 4, level: -46),
        cues: [
            SoundCue(voice: .glass(note: 81, length: 1.8, brightness: 1), part: .score, time: 0.5, level: -15, seed: 1),
            SoundCue(voice: .thump(high: 70, low: 44, length: 0.7, decay: 0.14), part: .score, time: 0.5, level: -15, seed: 2),
            SoundCue(voice: .key(.letter), part: .effects, time: 1, level: -14, seed: 3),
            SoundCue(voice: .whoosh, part: .effects, time: 2, level: -9, seed: 4),
            SoundCue(voice: .felt(note: 74, length: 0.9), part: .score, time: 3, offset: 0.1, level: -19, seed: 5)
        ],
        roomStop: 3
    )

    @Test func aSheetSoundsTheSameEveryTime() {
        let first = ScoreRenderer.render(sheet)
        #expect(first.count == SoundSignal.count(4))
        #expect(first == ScoreRenderer.render(sheet))
    }

    @Test func theFinishHoldsLoudnessAndPeaks() {
        let sound = ScoreRenderer.render(sheet)
        #expect(abs(Loudness.integrated(sound) - SoundFinish.loudness) < 0.5)
        #expect(Loudness.truePeak(sound) <= SoundFinish.ceiling + 0.05)
        // The 0.7 s fade ends in silence
        #expect(sound.left.suffix(10).allSatisfy { abs($0) < 1e-3 })
    }

    /// The room stops with the picture at the cut to black: only what's sent from then on rings.
    @Test func theRoomStopsAtTheCutToBlack() {
        var send = StereoSound(silence: SoundSignal.count(2))
        send.add(([1], [1]), gains: (1, 1), at: SoundSignal.count(0.5))
        let wet = SoundRoom.wet(send, stop: SoundSignal.count(1))
        let ringing = { (start: Double, end: Double) in vDSP.maximumMagnitude(wet.left[SoundSignal.count(start)..<SoundSignal.count(end)]) }
        #expect(ringing(0.6, 0.99) > 0)
        #expect(ringing(1.01, 2) == 0)
    }

    /// Written into a bundle once, then found by its sheet; another sheet is another file.
    @Test func theCacheKeepsASheetsSound() async throws {
        let bundle = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).motion")
        defer { try? FileManager.default.removeItem(at: bundle) }
        let url = try #require(try await SoundCache.sound(for: sheet, in: bundle))
        #expect(url == SoundCache.url(of: sheet, in: bundle))
        let read = try SoundCache.read(url)
        #expect(read.count == SoundSignal.count(4))
        // Apple Lossless at 24 bits: within a 24-bit step of what was made
        #expect(zip(read.left, ScoreRenderer.render(sheet).left).allSatisfy { abs($0 - $1) < 1e-6 })
        var quieter = sheet
        quieter.cues[0].level -= 6
        #expect(SoundCache.url(of: quieter, in: bundle) != url)
        #expect(try await SoundCache.sound(for: SoundCueSheet(length: 4), in: bundle) == nil)
    }

    /// Exported, a cue lands within 1 ms of where it was made, AAC's priming included, and ProRes carries
    /// the sound as PCM.
    @Test func anExportsSoundLandsOnItsFrames() async throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
            {"version": 1, "canvas": {"size": [320, 180], "frameRate": 30}, "scenes": [{"id": "a", "duration": 2, "layers": []}]}
            """#.utf8))
        let plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory)
        let click = SoundCueSheet(length: 2, cues: [SoundCue(voice: .key(.letter), part: .effects, time: 1, level: -14, seed: 9)])
        let bundle = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).motion")
        defer { try? FileManager.default.removeItem(at: bundle) }
        let sound = try #require(try await SoundCache.sound(for: click, in: bundle))
        let composition = try await MotionCompositionBuilder.composition(for: plan, sound: sound)
        let made = try SoundCache.read(sound).left

        let movie = bundle.appending(path: "click.mp4")
        try await ExportService.export(composition, to: movie, as: .hevc) { _ in }
        let exported = try await audio(of: AVURLAsset(url: movie))
        #expect(abs(lag(of: exported, against: made, near: 1)) <= SoundSignal.count(0.001))

        let proRes = bundle.appending(path: "click.mov")
        try await ExportService.export(composition, to: proRes, as: .proRes422) { _ in }
        let track = try #require(try await AVURLAsset(url: proRes).loadTracks(withMediaType: .audio).first)
        let format = try #require(try await track.load(.formatDescriptions).first)
        #expect(CMFormatDescriptionGetMediaSubType(format) == kAudioFormatLinearPCM)
    }

    /// The left channel of `asset`'s sound at 48 kHz.
    private func audio(of asset: AVURLAsset) async throws -> [Float] {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderAudioMixOutput(audioTracks: try await asset.loadTracks(withMediaType: .audio), audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false, AVSampleRateKey: SoundSignal.sampleRate, AVNumberOfChannelsKey: 2
        ])
        reader.add(output)
        #expect(reader.startReading())
        var samples: [Float] = []
        while let buffer = output.copyNextSampleBuffer() {
            let data = try #require(buffer.dataBuffer).dataBytes()
            data.withUnsafeBytes { samples += $0.bindMemory(to: Float.self) }
        }
        return stride(from: 0, to: samples.count, by: 2).map { samples[$0] }
    }

    /// How many samples later `signal` has `reference`'s sound around `time` seconds: the best match within
    /// 10 ms either way.
    private func lag(of signal: [Float], against reference: [Float], near time: Double) -> Int {
        let window = SoundSignal.count(time - 0.05)..<SoundSignal.count(time + 0.15)
        let reach = SoundSignal.count(0.01)
        let match = { (shift: Int) in vDSP.dot(reference[window], signal[(window.lowerBound + shift)..<(window.upperBound + shift)]) }
        return (-reach...reach).max { match($0) < match($1) } ?? .max
    }
}
