//
//  ExportServiceTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation
import CoreImage
import ImageIO
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

        #expect(ExportFormat.mp4.outputURL(for: video).path() == "/Users/me/Movies/Demo-edited.mp4")
        #expect(ExportFormat.proRes.outputURL(for: video).path() == "/Users/me/Movies/Demo-edited.mov")
        #expect(ExportFormat.gif.outputURL(for: video).path() == "/Users/me/Movies/Demo-edited.gif")
    }

    @Test func theClipboardGetsAFolderOfItsOwn() {
        let video = URL(filePath: "/Users/me/Movies/Demo.mov")
        let first = ExportDestination.clipboard.outputURL(for: video, format: .gif)
        let second = ExportDestination.clipboard.outputURL(for: video, format: .gif)

        #expect(first.lastPathComponent == "Demo-edited.gif")
        #expect(first.deletingLastPathComponent() != second.deletingLastPathComponent())
        #expect(first.path().hasPrefix(URL.temporaryDirectory.path()))
        #expect(ExportDestination.recordingFolder.outputURL(for: video, format: .gif) == ExportFormat.gif.outputURL(for: video))
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
        let output = ExportFormat.mp4.outputURL(for: video)

        try await ExportService.export(composition, to: output, as: ExportSettings(quality: .studio)) { _ in }

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
        var project = EditorProject()
        project.canvas.aspect = .standard
        let plan = await RenderPlan.build(project: project, source: source, resources: .none, target: RenderTarget(shorterSide: 120))
        var composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        composition.videoComposition = CompositionBuilder.videoComposition(for: source, plan: plan, frameRate: 15)
        let output = ExportFormat.mp4.outputURL(for: video)

        try await ExportService.export(composition, to: output, as: ExportSettings()) { _ in }

        let track = try #require(try await AVURLAsset(url: output).loadTracks(withMediaType: .video).first)
        let (size, frameRate) = try await track.load(.naturalSize, .nominalFrameRate)
        #expect(size == CGSize(width: 160, height: 120))
        #expect(abs(frameRate - 15) < 0.5)
    }

    /// Frames of grain keep an encoder busy, so it spends what it's given: the file's average bitrate is
    /// the quality's target, give or take what a short take lets the rate control settle. Flat frames would
    /// come far under it.
    @Test func anMP4ReachesTheQualitysBitrate() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let size = CGSize(width: 640, height: 360)
        try await TestRecording.write(to: video, size: size, frameCount: 60, frameRate: 30, noisy: true)
        let source = try await EditorSourceLoader.load(videoURL: video)
        var project = EditorProject()
        project.canvas = .plain
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)

        // Not Web (Low): 0.025 bit per pixel is under what this content costs at the encoder's coarsest (1.5×)
        for quality in [ExportQuality.studio, .socialMedia, .web] {
            let settings = ExportSettings(quality: quality)
            let output = folder.appending(path: "\(quality).mp4")
            try await ExportService.export(composition, to: output, as: settings) { _ in }

            let track = try #require(try await AVURLAsset(url: output).loadTracks(withMediaType: .video).first)
            let measured = Double(try await track.load(.estimatedDataRate))
            let target = try #require(settings.videoBitRate(size: size, frameRate: 30))
            print("MP4 \(quality): \(Int(measured)) bit/s measured, \(Int(target)) target (\((measured / target).formatted(.number.precision(.fractionLength(2)))))")
            #expect(measured < target * 1.4 && measured > target * 0.6, "\(quality)")
        }
    }

    @Test func aMovieHasItsAudioAsAACInAnMP4AndPCMInProRes() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: videoSize, frameCount: 15, frameRate: 30, withTone: true)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let plan = await RenderPlan.build(project: EditorProject(), source: source, resources: .none)
        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: AudioMixSettings())

        for (format, audioCodec) in [(ExportFormat.mp4, kAudioFormatMPEG4AAC), (.proRes, kAudioFormatLinearPCM)] {
            let output = format.outputURL(for: video)
            try await ExportService.export(composition, to: output, as: ExportSettings(format: format)) { _ in }

            let track = try #require(try await AVURLAsset(url: output).loadTracks(withMediaType: .audio).first)
            let description = try #require(try await track.load(.formatDescriptions).first)
            #expect(description.mediaSubType.rawValue == audioCodec, "\(format)")
        }
    }

    @Test func proResIsTheFlavourOfTheQuality() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: videoSize, frameCount: 5, frameRate: 30)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let plan = await RenderPlan.build(project: EditorProject(), source: source, resources: .none)
        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: AudioMixSettings())
        let flavours: [(ExportQuality, String)] = [(.studio, "apch"), (.socialMedia, "apcn"), (.web, "apcs"), (.webLow, "apco")]

        for (quality, fourCC) in flavours {
            let output = folder.appending(path: "\(quality).mov")
            try await ExportService.export(composition, to: output, as: ExportSettings(format: .proRes, quality: quality)) { _ in }

            let track = try #require(try await AVURLAsset(url: output).loadTracks(withMediaType: .video).first)
            let description = try #require(try await track.load(.formatDescriptions).first)
            #expect(fourCC == description.mediaSubType.description.trimmingCharacters(in: CharacterSet(charactersIn: "'")), "\(quality)")
        }
    }

    @Test func keepsATransparentBackgroundInProRes4444() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: videoSize, frameCount: 5, frameRate: 30)
        let source = try await EditorSourceLoader.load(videoURL: video)
        var project = EditorProject()
        project.canvas = CanvasStyle(padding: 0.1, cornerRadius: 0, shadow: 0, background: .transparent)
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        let settings = ExportSettings.initial(transparentCanvas: true)
        #expect(settings.format == .proRes)
        let output = settings.format.outputURL(for: video)

        try await ExportService.export(composition, to: output, as: settings) { _ in }

        let reader = try AVAssetReader(asset: AVURLAsset(url: output))
        let track = try #require(try await reader.asset.loadTracks(withMediaType: .video).first)
        let description = try #require(try await track.load(.formatDescriptions).first)
        #expect(description.mediaSubType == .proRes4444)
        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(trackOutput)
        #expect(reader.startReading())
        let frame = try #require(trackOutput.copyNextSampleBuffer()?.imageBuffer)
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }
        let pixels = try #require(CVPixelBufferGetBaseAddress(frame)).assumingMemoryBound(to: UInt8.self)
        let rowBytes = CVPixelBufferGetBytesPerRow(frame)
        // Alpha, the fourth byte: clear in the padding, opaque in the video (ProRes 4444 rounds it to
        // 254 on macOS 26.6)
        #expect(pixels[2 * rowBytes + 2 * 4 + 3] == 0)
        #expect(pixels[120 * rowBytes + 160 * 4 + 3] >= 254)
    }

    @Test func keepsHDRInMP4AndProRes() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: videoSize, frameCount: 5, frameRate: 30, hdr: true) { _ in 0x80 }
        let source = try await EditorSourceLoader.load(videoURL: video)
        #expect(source.dynamicRange == .pq)

        for format in [ExportFormat.mp4, .proRes] {
            let settings = ExportSettings(format: format)
            let plan = await RenderPlan.build(project: EditorProject(), source: source, resources: .none, target: RenderTarget(keepsHDR: settings.keepsHDR))
            let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: AudioMixSettings())
            let output = format.outputURL(for: video)

            try await ExportService.export(composition, to: output, as: settings) { _ in }

            let track = try #require(try await AVURLAsset(url: output).loadTracks(withMediaType: .video).first)
            let description = try await track.load(.formatDescriptions).first
            #expect(DynamicRange(of: description) == .pq, "\(format)")
        }
    }

    @Test func aGIFHasEveryFrameAtTheCompositionsSizeLoopingForever() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        // Frame n is flat grey at level 10 n: each one's own frame, not a neighbour's or the first's
        try await TestRecording.write(to: video, size: videoSize, frameCount: 15, frameRate: 30) { UInt8($0 * 10) }
        let source = try await EditorSourceLoader.load(videoURL: video)
        var project = EditorProject()
        project.canvas = .plain
        let plan = await RenderPlan.build(project: project, source: source, resources: .none, target: RenderTarget(keepsHDR: false))
        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        let output = ExportFormat.gif.outputURL(for: video)
        var progress: [Double] = []

        try await ExportService.export(composition, to: output, as: ExportSettings(format: .gif)) { progress.append($0) }

        let gif = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
        #expect(CGImageSourceGetCount(gif) == 15)
        let fileProperties = CGImageSourceCopyProperties(gif, nil) as? [CFString: Any]
        #expect((fileProperties?[kCGImagePropertyGIFDictionary] as? [CFString: Any])?[kCGImagePropertyGIFLoopCount] as? Int == 0)
        var delays: [Double] = []
        var levels: [Int] = []
        for index in 0..<15 {
            let image = try #require(CGImageSourceCreateImageAtIndex(gif, index, nil))
            #expect(image.width == 320 && image.height == 240)
            levels.append(Int(CIImage(cgImage: image).pixel(at: CGPoint(x: 10, y: 10))[0]))
            let properties = CGImageSourceCopyPropertiesAtIndex(gif, index, nil) as? [CFString: Any]
            delays.append((properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any])?[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? 0)
        }
        // 30 fps in whole centiseconds: 3, 4, 3 repeating, 0.5 s in all
        #expect(delays.map { Int(($0 * 100).rounded()) } == (0..<15).map { GIFEncoder.delay(ofFrame: $0, frameRate: 30) })
        #expect(abs(delays.reduce(0, +) - 0.5) < 0.001)
        #expect(zip(levels, levels.dropFirst()).allSatisfy { $1 > $0 }, "\(levels)")
        #expect(abs(levels[14] - 140) <= 8, "\(levels)")
        #expect(progress.last == 1)
    }

    @Test func cancellingAnExportRemovesTheFile() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: video, size: videoSize, frameCount: 60, frameRate: 30)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let plan = await RenderPlan.build(project: EditorProject(), source: source, resources: .none)
        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: AudioMixSettings())

        for format in ExportFormat.allCases {
            let output = format.outputURL(for: video)
            let export = Task { try await ExportService.export(composition, to: output, as: ExportSettings(format: format)) { _ in } }
            export.cancel()

            await #expect(throws: CancellationError.self) { try await export.value }
            #expect(!FileManager.default.fileExists(atPath: output.path()), "\(format)")
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
