//
//  ExportServiceTests.swift
//  BetterCaptureTests
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation
import CoreImage
import Testing
@testable import BetterCapture

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
        project.clickHighlights.size = 100
        project.clickHighlights.color = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
        let plan = await RenderPlan.build(project: project, source: source, keyLabels: nil, arrow: nil)
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

    /// Writes telemetry for a display recorded at 1× with one left click.
    private func writeTelemetry(clickAt location: CGPoint, time: Double) throws {
        var telemetry = InputTelemetry(capture: .init(kind: .display, videoSize: videoSize), keystrokesAvailable: false)
        let screen = CGRect(origin: .zero, size: videoSize)
        telemetry.geometry = [.init(time: 0, screenRect: screen, contentRect: screen, contentScale: 1, scaleFactor: 1)]
        telemetry.clicks = [.init(time: time, location: location, button: .left, isDown: true, clickCount: 1)]
        try JSONEncoder().encode(telemetry).write(to: InputTelemetry.sidecarURL(for: video))
    }
}
