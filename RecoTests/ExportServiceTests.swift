//
//  ExportServiceTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation
import CoreImage
import Testing
@testable import Reco

@MainActor
struct ExportServiceTests {

    private let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
    private let videoSize = CGSize(width: 320, height: 240)

    private var video: URL {
        folder.appending(path: "recording.mov")
    }

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    @Test func outputSitsNextToTheRecording() {
        let video = URL(filePath: "/Users/me/Movies/Demo.mov")

        #expect(ExportFormat.hevc.outputURL(for: video).path() == "/Users/me/Movies/Demo-edited.mp4")
        #expect(ExportFormat.proRes422.outputURL(for: video).path() == "/Users/me/Movies/Demo-edited.mov")
    }

    @Test func exportsTheRecordingWithItsOverlaysDrawn() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: videoSize, frameCount: 15, frameRate: 30)
        try writeTelemetry(clickAt: CGPoint(x: 100, y: 80), time: 0.2)
        let source = try await EditorSourceLoader.load(videoURL: video)
        var project = EditorProject()
        project.canvas = .plain
        project.clickHighlights.size = 100
        project.clickHighlights.color = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        let output = ExportFormat.h264.outputURL(for: video)

        try await ExportService.export(composition, to: output, as: .h264) { _ in }

        let exported = AVURLAsset(url: output)
        #expect(abs(try await exported.load(.duration).seconds - 0.5) < 1.0 / 30)
        let generator = AVAssetImageGenerator(asset: exported)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let frame = CIImage(cgImage: try await generator.image(at: CMTime(value: 6, timescale: 30)).image)
        // The ring's faint red fill at the click, 80 px from the top; black elsewhere
        let click = frame.pixel(at: CGPoint(x: 100, y: videoSize.height - 80))
        #expect(click[0] > 60 && click[1] < 40)
        #expect(frame.pixel(at: CGPoint(x: 250, y: 40))[0] < 30)
    }

    @Test func exportsAtTheChosenSizeAndFrameRate() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: videoSize, frameCount: 15, frameRate: 30)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let project = EditorProject()
        let plan = await RenderPlan.build(project: project, source: source, resources: .none, target: RenderTarget(shorterSide: 120))
        var composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        composition.videoComposition = CompositionBuilder.videoComposition(for: source, plan: plan, frameRate: 15)
        let output = ExportFormat.hevc.outputURL(for: video)

        try await ExportService.export(composition, to: output, as: .hevc) { _ in }

        let track = try #require(try await AVURLAsset(url: output).loadTracks(withMediaType: .video).first)
        let (size, frameRate) = try await track.load(.naturalSize, .nominalFrameRate)
        #expect(size == CGSize(width: 160, height: 120))
        #expect(abs(frameRate - 15) < 0.5)
    }

    @Test func exportsALoopingGIFWhoseRepeatedFramesOnlyShowLonger() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        // Half a second dark, then half a second light
        try await TestRecording.write(to: video, size: videoSize, frameCount: 30, frameRate: 30) { $0 < 15 ? 0 : 200 }
        let source = try await EditorSourceLoader.load(videoURL: video)
        var project = EditorProject()
        project.canvas = .plain
        let plan = await RenderPlan.build(project: project, source: source, resources: .none, target: RenderTarget(shorterSide: 120, keepsHDR: false))
        var composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        composition.videoComposition = CompositionBuilder.videoComposition(for: source, plan: plan, frameRate: 25)
        let output = ExportFormat.gif.outputURL(for: video)
        #expect(output.lastPathComponent == "recording-edited.gif")

        try await ExportService.export(composition, to: output, as: .gif) { _ in }

        let gif = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
        let count = CGImageSourceGetCount(gif)
        #expect(count == 2)
        let delays = (0..<count).compactMap { index in
            let properties = CGImageSourceCopyPropertiesAtIndex(gif, index, nil) as? [CFString: Any]
            return (properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any])?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        }
        #expect(abs(delays.reduce(0, +) - 1) < 0.001)
        let last = try #require(CGImageSourceCreateImageAtIndex(gif, count - 1, nil))
        #expect(last.width == 160 && last.height == 120)
        #expect(CIImage(cgImage: last).pixel(at: CGPoint(x: 80, y: 60))[0] > 150)
    }

    @Test func drawsTheFrameAtATimeAsAnExportWould() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: videoSize, frameCount: 30, frameRate: 30) { $0 < 15 ? 0 : 200 }
        let source = try await EditorSourceLoader.load(videoURL: video)
        var project = EditorProject()
        project.canvas = .plain
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)

        let dark = try await ExportService.frame(of: composition, at: CMTime(value: 5, timescale: 30))
        let light = try await ExportService.frame(of: composition, at: CMTime(value: 20, timescale: 30))

        #expect(dark.width == 320 && dark.height == 240)
        #expect(CIImage(cgImage: dark).pixel(at: CGPoint(x: 160, y: 120))[0] < 40)
        #expect(CIImage(cgImage: light).pixel(at: CGPoint(x: 160, y: 120))[0] > 150)
    }

    @Test func gifSettingsAreSmallAndInTimeAndVideosKeepTheOriginal() {
        let movie = ExportSettings(format: .hevc, resolution: 1080, frameRate: 30)
        #expect(movie.conformed(shorterSide: 2160, frameRate: 60) == movie)
        #expect(movie.conformed(shorterSide: 1080, frameRate: 30) == ExportSettings(format: .hevc))

        var gif = movie
        gif.format = .gif
        #expect(gif.conformed(shorterSide: 2160, frameRate: 60) == ExportSettings(format: .gif, resolution: 540, frameRate: 25))
        // A small canvas is exported as it is
        #expect(gif.conformed(shorterSide: 400, frameRate: 30) == ExportSettings(format: .gif, resolution: nil, frameRate: 25))
        #expect(ExportSettings.frameRates(below: 30, for: .gif) == [25])
        let chosen = ExportSettings(format: .gif, resolution: 720, frameRate: 50)
        #expect(chosen.conformed(shorterSide: 2160, frameRate: 60) == chosen)
        // Back to a video: its size and rate aren't a GIF's
        #expect(ExportSettings(format: .h264, resolution: 540, frameRate: 25).conformed(shorterSide: 2160, frameRate: 60) == ExportSettings(format: .h264))
    }

    @Test func keepsATransparentBackgroundInProRes4444() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: videoSize, frameCount: 5, frameRate: 30)
        let source = try await EditorSourceLoader.load(videoURL: video)
        var project = EditorProject()
        project.canvas = CanvasStyle(padding: 0.1, cornerRadius: 0, shadow: 0, background: .transparent)
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        let output = ExportFormat.proRes4444.outputURL(for: video)

        try await ExportService.export(composition, to: output, as: .proRes4444) { _ in }

        let reader = try AVAssetReader(asset: AVURLAsset(url: output))
        let track = try #require(try await reader.asset.loadTracks(withMediaType: .video).first)
        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(trackOutput)
        #expect(reader.startReading())
        let frame = try #require(trackOutput.copyNextSampleBuffer()?.imageBuffer)
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }
        let pixels = try #require(CVPixelBufferGetBaseAddress(frame)).assumingMemoryBound(to: UInt8.self)
        let rowBytes = CVPixelBufferGetBytesPerRow(frame)
        // Alpha, the fourth byte: clear in the padding, opaque in the video
        #expect(pixels[2 * rowBytes + 2 * 4 + 3] == 0)
        #expect(pixels[120 * rowBytes + 160 * 4 + 3] == 255)
    }

    @Test func keepsHDRUnlessTheFormatIsH264() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: videoSize, frameCount: 5, frameRate: 30, hdr: true) { _ in 0x80 }
        let source = try await EditorSourceLoader.load(videoURL: video)
        #expect(source.dynamicRange == .pq)

        for format in [ExportFormat.hevc, .proRes422, .h264] {
            let plan = await RenderPlan.build(project: EditorProject(), source: source, resources: .none, target: RenderTarget(keepsHDR: format.keepsHDR))
            let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: AudioMixSettings())
            let output = format.outputURL(for: video)

            try await ExportService.export(composition, to: output, as: format) { _ in }

            let track = try #require(try await AVURLAsset(url: output).loadTracks(withMediaType: .video).first)
            let description = try await track.load(.formatDescriptions).first
            // H.264 is converted to SDR
            #expect(DynamicRange(of: description) == (format.keepsHDR ? .pq : .sdr), "\(format.rawValue)")
        }
    }

    /// Writes telemetry for a display recorded at 1× with one left click.
    private func writeTelemetry(clickAt location: CGPoint, time: Double) throws {
        var telemetry = InputTelemetry(capture: .init(kind: .display, videoSize: videoSize), keystrokesAvailable: false)
        let screen = CGRect(origin: .zero, size: videoSize)
        telemetry.geometry = [.init(time: 0, screenRect: screen, contentRect: screen, contentScale: 1, scaleFactor: 1)]
        telemetry.clicks = [.init(time: time, location: location, button: .left, isDown: true, clickCount: 1)]
        try JSONEncoder().encode(telemetry).write(to: InputTelemetry.sidecarURL(for: video))
    }
}
