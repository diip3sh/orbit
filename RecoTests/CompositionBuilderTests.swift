//
//  CompositionBuilderTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import AVFoundation
import CoreImage
import Testing
@testable import Reco

@MainActor
struct CompositionBuilderTests {

    private let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)

    private var video: URL {
        folder.appending(path: "recording.mov")
    }

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    @Test func fadesAudioOutBeforeEveryCutAndInAfterIt() {
        // Kept: 1..<4 (output 0..<3) and 6..<10 (output 3..<7)
        let fades = CompositionBuilder.audioFades(for: TimeMap(cuts: [0..<1, 4..<6], sourceDuration: 10, frameRate: 4))

        #expect(fades.map(\.fadesIn) == [true, false, true])
        #expect(fades.map(\.range.lowerBound).elementsEqual([0, 2.975, 3]) { abs($0 - $1) < 1e-9 })
        #expect(fades.map(\.range.upperBound).elementsEqual([0.025, 3, 3.025]) { abs($0 - $1) < 1e-9 })
    }

    @Test func aKeptRangeShorterThanTwoFadesFadesOverHalfItsLength() {
        // Kept: one 10 ms frame between two cuts
        let fades = CompositionBuilder.audioFades(for: TimeMap(cuts: [0..<1, 1.01..<2], sourceDuration: 2, frameRate: 100))

        #expect(fades.map(\.range.upperBound).elementsEqual([0.005, 0.01]) { abs($0 - $1) < 1e-9 })
    }

    @Test func exportLeavesOutTheCuts() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: CGSize(width: 64, height: 48), frameCount: 30, frameRate: 30, withTone: true) {
            UInt8($0 * 8)
        }
        let source = try await EditorSourceLoader.load(videoURL: video)
        // Frames 6 to 14 are cut
        let project = EditorProject(cuts: [0.2..<0.5])
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        let output = ExportFormat.mp4.outputURL(for: video)

        try await ExportService.export(composition, to: output, as: ExportSettings(quality: .studio)) { _ in }

        let exported = AVURLAsset(url: output)
        #expect(abs(try await exported.load(.duration).seconds - 0.7) < 1.0 / 30)
        #expect(try await exported.loadTracks(withMediaType: .audio).count == 1)
        // Neighbouring frames differ by about 8 levels
        #expect(abs(try await level(ofFrame: 5, in: exported) - (try await level(ofFrame: 5, in: source.asset))) <= 3)
        #expect(abs(try await level(ofFrame: 6, in: exported) - (try await level(ofFrame: 15, in: source.asset))) <= 3)
    }

    @Test func mixFadesAtTheCutAndPlaysEachTrackAtItsVolume() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: CGSize(width: 64, height: 48), frameCount: 30, frameRate: 30, withTone: true)
        let source = try await EditorSourceLoader.load(videoURL: video)
        var project = EditorProject(cuts: [0.2..<0.5])
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)

        let full = try await mixedAudio(of: try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio))
        // The cut is at 0.2 s in the output
        #expect(abs(full.count - 33_600) < 100)
        #expect(peak(of: full, from: 0.1, to: 0.15) > 0.45)
        #expect(peak(of: full, from: 0.199, to: 0.201) < 0.05)
        #expect(peak(of: full, from: 0.25, to: 0.3) > 0.45)

        project.audio[track: 0].volume = 0.5
        let half = try await mixedAudio(of: try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio))
        #expect(abs(peak(of: half, from: 0.1, to: 0.15) - 0.25) < 0.03)

        project.audio[track: 0].isMuted = true
        let muted = try await mixedAudio(of: try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio))
        #expect(peak(of: muted, from: 0, to: 0.7) < 0.001)
    }

    @Test func clickSoundsAreMixedAtTheirVolumeAndLeftOutOfCuts() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: CGSize(width: 64, height: 48), frameCount: 30, frameRate: 30, withTone: true)
        let source = try await EditorSourceLoader.load(videoURL: video)
        // Cut 0.2 to 0.5. Clicks at 0.1 (output 0.1), 0.3 (cut) and 0.6 (output 0.3)
        var project = EditorProject(cuts: [0.2..<0.5])
        project.audio[track: 0].isMuted = true
        project.audio.clickVolume = 0.5
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let clicks = folder.appending(path: "clicks.caf")
        try await ClickSoundWriter.write(onsets: [4_800, 14_400, 28_800], frameCount: 52_800, to: clicks)
        let loudest = try #require(ClickSound.samples.map(abs).max())

        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio, extra: ExtraAudio(clicks: clicks))
        let mixed = try await mixedAudio(of: composition)

        #expect(try await composition.asset.loadTracks(withMediaType: .audio).count == 2)
        #expect(composition.extraAudio.clicks == clicks)
        #expect(abs(peak(of: mixed, from: 0.1, to: 0.12) - loudest * 0.5) < 0.02)
        #expect(abs(peak(of: mixed, from: 0.3, to: 0.32) - loudest * 0.5) < 0.02)
        // Nothing of the click in the cut, nor between the others
        #expect(peak(of: mixed, from: 0.13, to: 0.29) < 0.001)

        project.audio.clickVolume = 1
        let louder = try await mixedAudio(of: try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio, extra: ExtraAudio(clicks: clicks)))
        #expect(abs(peak(of: louder, from: 0.1, to: 0.12) - loudest) < 0.02)

        // The recording's own track is still muted, and without the file there is only it
        let plain = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        #expect(try await plain.asset.loadTracks(withMediaType: .audio).count == 1)
    }

    @Test func loopsFillTheOutputExactlyAndTheLastOneIsCut() {
        func seconds(_ ranges: [CMTimeRange]) -> [[Double]] {
            ranges.map { [$0.start.seconds, $0.duration.seconds] }
        }
        func time(_ seconds: Double) -> CMTime {
            CMTime(seconds: seconds, preferredTimescale: 600)
        }

        #expect(seconds(CompositionBuilder.loopRanges(length: time(2), filling: time(6))) == [[0, 2], [2, 2], [4, 2]])
        #expect(seconds(CompositionBuilder.loopRanges(length: time(2), filling: time(5))) == [[0, 2], [2, 2], [4, 1]])
        #expect(seconds(CompositionBuilder.loopRanges(length: time(10), filling: time(3))) == [[0, 3]])
        #expect(CompositionBuilder.loopRanges(length: .zero, filling: time(3)).isEmpty)
        #expect(CompositionBuilder.loopRanges(length: time(2), filling: .zero).isEmpty)
    }

    @Test func backgroundMusicFadesInOverASecondAndOutOverTwoButNeverMoreThanAQuarter() {
        let long = CompositionBuilder.backgroundFades(outputDuration: 60)
        #expect(long.in == 0..<1 && long.out == 58..<60)
        let short = CompositionBuilder.backgroundFades(outputDuration: 6)
        #expect(short.in == 0..<1 && short.out == 4.5..<6)
        let tiny = CompositionBuilder.backgroundFades(outputDuration: 2)
        #expect(tiny.in == 0..<0.5 && tiny.out == 1.5..<2)
    }

    @Test func backgroundMusicLoopsToTheOutputsEndNoFurtherAndRunsThroughCuts() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: CGSize(width: 64, height: 48), frameCount: 30, frameRate: 30, withTone: true)
        // Half a second, so a 0.7 s output holds it once and a bit
        let music = folder.appending(path: "music.mov")
        try await TestRecording.write(to: music, size: CGSize(width: 64, height: 48), frameCount: 15, frameRate: 30, withTone: true)
        let source = try await EditorSourceLoader.load(videoURL: video)
        // Cut 0.2 to 0.5: the output is 0.7 s, with the fades 0.175 s each
        var project = EditorProject(cuts: [0.2..<0.5])
        project.audio[track: 0].isMuted = true
        project.audio.background = BackgroundAudio(bookmark: Data(), name: "music", track: .init(volume: 0.8))
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let extra = ExtraAudio(background: music)

        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio, extra: extra)
        let mixed = try await mixedAudio(of: composition)

        #expect(try await composition.asset.loadTracks(withMediaType: .audio).count == 2)
        #expect(abs(try await composition.asset.load(.duration).seconds - 0.7) < 0.001)
        #expect(abs(Double(mixed.count) / TestRecording.sampleRate - 0.7) < 0.003)
        // Full volume between the fades, through the cut (0.2 s) and the loop's seam (0.5 s), and silent at both ends
        #expect(abs(peak(of: mixed, from: 0.2, to: 0.5) - 0.4) < 0.03)
        #expect(peak(of: mixed, from: 0, to: 0.002) < 0.01)
        #expect(peak(of: mixed, from: mixed.count - 100, to: mixed.count) < 0.02)

        project.audio.background?.track.isMuted = true
        let muted = try await mixedAudio(of: try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio, extra: extra))
        #expect(peak(of: muted, from: 0, to: 0.7) < 0.001)
    }

    /// The grey level of frame `index` of a 30 fps video.
    private func level(ofFrame index: Int, in asset: AVURLAsset) async throws -> Int {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = CIImage(cgImage: try await generator.image(at: CMTime(value: CMTimeValue(index), timescale: 30)).image)
        return Int(image.pixel(at: CGPoint(x: 32, y: 24))[1])
    }

    /// The composition's audio as its mix plays it: mono samples at the test recording's rate.
    private func mixedAudio(of composition: EditorComposition) async throws -> [Float] {
        // AVComposition is immutable but not Sendable-annotated, so loading its tracks off the main actor is safe
        nonisolated(unsafe) let asset = composition.asset
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderAudioMixOutput(audioTracks: try await asset.loadTracks(withMediaType: .audio), audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false,
            AVSampleRateKey: TestRecording.sampleRate, AVNumberOfChannelsKey: 1
        ])
        output.audioMix = composition.audioMix
        reader.add(output)
        #expect(reader.startReading())

        var samples: [Float] = []
        while let buffer = output.copyNextSampleBuffer() {
            let data = try #require(buffer.dataBuffer).dataBytes()
            data.withUnsafeBytes { samples += $0.bindMemory(to: Float.self) }
        }
        #expect(reader.status == .completed)
        return samples
    }

    /// The loudest sample between two output times.
    private func peak(of samples: [Float], from start: Double, to end: Double) -> Float {
        peak(of: samples, from: Int(start * TestRecording.sampleRate), to: Int(end * TestRecording.sampleRate))
    }

    private func peak(of samples: [Float], from start: Int, to end: Int) -> Float {
        samples[start..<end].map(abs).max() ?? 0
    }
}
