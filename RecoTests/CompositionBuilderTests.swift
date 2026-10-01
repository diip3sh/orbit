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
        let output = ExportFormat.h264.outputURL(for: video)

        try await ExportService.export(composition, to: output, as: .h264) { _ in }

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
        samples[Int(start * TestRecording.sampleRate)..<Int(end * TestRecording.sampleRate)].map(abs).max() ?? 0
    }
}
