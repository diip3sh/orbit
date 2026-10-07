//
//  PauseCutExportTests.swift
//  RecoTests
//

import AVFoundation
import Carbon.HIToolbox
import CoreImage
import CoreVideo
import ScreenCaptureKit
import Testing
@testable import Reco

/// A recording paused while it ran and cut in the editor afterwards, exported: what remains of the
/// frames, the click highlights, the key chips and the cursor must all land on the output timeline.
///
/// The fixture walks the whole path with real parts: the pause is `AssetWriter`'s (samples dropped,
/// host-clock telemetry rebased at stop, as `InputTelemetryRecorder` does), the cut is
/// `EditorProject`'s and the frames are `ExportService`'s. 4 s are recorded from host second 1000,
/// paused from 1001 to 1002, then cut from 0.7 s to 1.2 s: 4 s of footage become 2.5 s.
@MainActor
@Suite(.serialized)
struct PauseCutExportTests {

    private let videoSize = CGSize(width: 320, height: 240)
    private let frameRate = 30
    private let outputFrameCount = 75
    private let defaults = TemporaryDefaults()

    /// The host-clock second the recording starts at, so the anchor's offset is cut too.
    private let anchor = 1000.0

    /// When the recording was paused and resumed, in host-clock seconds.
    private let pause = 1.0
    private let resume = 2.0

    /// What the editor cuts, on the recording's own timeline: 0.5 s, 15 frames from 0.7 s.
    private let cut = 0.7..<1.2

    /// The output frame the cut starts at (0.7 s at 30 fps).
    private var cutFrame: Int {
        Int((cut.lowerBound * Double(frameRate)).rounded())
    }

    /// The click points, in the screen points telemetry stores (top-left origin).
    private let clickBeforeCut = CGPoint(x: 80, y: 60)
    private let clickInsideCut = CGPoint(x: 40, y: 200)
    private let clickWhilePaused = CGPoint(x: 300, y: 20)
    private let clickAfterCut = CGPoint(x: 200, y: 140)

    /// Where the cursor rests. Each click glides it onto its own point, exactly at the click's time.
    private let cursorRest = CGPoint(x: 240, y: 200)

    /// The clicks as recorded, at the host-clock offset each happened (before the pauses are cut,
    /// before the editor cuts). The output frame each must appear on:
    /// 0.5 s is source 0.5 and output 0.5 (frame 15), 0.8 s is source 0.8 and inside the cut, 1.5 s
    /// is during the pause and dropped at stop, 2.5 s is source 1.5 and output 1.0 (frame 30).
    private var clicks: [(offset: Double, location: CGPoint)] {
        [(0.5, clickBeforeCut), (0.8, clickInsideCut), (1.5, clickWhilePaused), (2.5, clickAfterCut)]
    }

    /// The keys as recorded, all the right arrow ("→"). 0.3 s is source 0.3 and output 0.3 (frame
    /// 9), 0.9 s is inside the cut, 1.5 s is during the pause, 3.4 s is source 2.4 and output 1.9
    /// (frame 57).
    private var keys: [Double] {
        [0.3, 0.9, 1.5, 3.4]
    }

    /// Where a key chip is drawn: centred at the bottom of the video, 6% of its shorter side tall,
    /// 0.8 of that above the edge. Wider than the chip, and clear of the clicks and the cursor, so
    /// the darkest pixel in it is the chip's dark backing whenever one is up.
    private let chipBox = CGRect(x: 130, y: 13, width: 60, height: 12)

    // MARK: - Tests

    @Test func theFramesAndOverlaysThatRemainSurviveThePauseAndTheCut() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: InputTelemetry.sidecarURL(for: url))
        }

        // 4 s of frames, paused from 1 s to 2 s: the three seconds outside the pause are written.
        // One frame per 25 ms, as a real capture delivers them: appended as fast as possible the
        // encoder's queue fills, and the drain fills every slot in between with the frame it holds
        // (see `AssetWriter.drainVideo`), which leaves the file's frames all alike.
        let writer = AssetWriter()
        try writer.setup(url: url, settings: store(), videoSize: videoSize)
        try writer.startWriting()
        for index in 0..<(4 * frameRate) {
            if index == frameRate { writer.pause(at: hostTime(pause)) }
            if index == 2 * frameRate { writer.resume(at: hostTime(resume)) }
            writer.appendVideoSample(try videoFrame(level: level(ofSourceFrame: index), at: index))
            try await Task.sleep(for: .milliseconds(25))
        }
        // Both are read before finishing: it resets them
        let pauses = writer.pauseIntervals
        let sessionStart = writer.sessionStartTime.seconds

        let result = try await writer.finishWriting()
        #expect(result.videoFrameCount == 3 * frameRate, "the second inside the pause is cut")

        // What the recorder writes at stop: every event rebased onto the file's own timeline
        let duration = try await AVURLAsset(url: result.url).load(.duration).seconds
        try JSONEncoder().encode(recordedTelemetry.rebased(anchor: sessionStart, duration: duration, pauses: pauses))
            .write(to: InputTelemetry.sidecarURL(for: result.url))

        // The editor: a red ring 60 px wide for 0.2 s, a plain canvas, and a cut between the clicks
        var project = EditorProject(cuts: [cut])
        project.canvas = .plain
        project.clickHighlights.size = 60
        project.clickHighlights.duration = 0.2
        project.clickHighlights.color = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)

        let source = try await EditorSourceLoader.load(videoURL: result.url)
        #expect(source.telemetry != nil, "\(String(describing: source.telemetryError))")
        let plan = await RenderPlan.build(project: project, source: source, resources: resources)
        let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        let output = ExportFormat.mp4.outputURL(for: result.url)
        defer { try? FileManager.default.removeItem(at: output) }

        try await ExportService.export(composition, to: output, as: ExportSettings(quality: .studio)) { _ in }

        let exportedDuration = try await AVURLAsset(url: output).load(.duration).seconds
        #expect(abs(exportedDuration - 2.5) < 1.0 / Double(frameRate), "the cut and the pause are gone")
        let recorded = try await frames(of: result.url)
        let exported = try await frames(of: output).map(measure)
        #expect(recorded.count == 3 * frameRate, "the recording's frames")
        #expect(exported.count == outputFrameCount, "the export's frames")
        guard recorded.count == 3 * frameRate, exported.count == outputFrameCount else { return }

        // Every exported frame is the recording's own frame at that point of the output timeline:
        // nothing is read from the cut, and nothing is missing after it
        assertFootage(exported, against: recorded)
        assertRings(exported)
        assertChips(exported)
        assertCursor(exported)
    }

    // MARK: - What the export must show

    /// The recording's frames in bands of 8, 14 grey levels apart, so a frame's level says which
    /// eighth of a second of the recording it is. A shift of more than 0.13 s changes it.
    private func assertFootage(_ exported: [Measured], against recorded: [Frame]) {
        for index in exported.indices {
            let expected = level(of: recorded[sourceFrame(atOutputFrame: index)])
            #expect(abs(exported[index].level - expected) <= 4, "the footage of frame \(index)")
        }
    }

    /// A ring shows for its 0.2 s from the click's own output frame, around its own click, and
    /// nothing is left of the click the cut removed: at the cut's edge its ring would be up from
    /// frame 21 on.
    private func assertRings(_ exported: [Measured]) {
        for index in 15...17 {
            #expect(exported[index].rednessBeforeCut > 120, "the first ring, frame \(index)")
            #expect(exported[index].rednessAfterCut < 40, "no ring at the second click, frame \(index)")
        }
        for index in 30...32 {
            #expect(exported[index].rednessAfterCut > 120, "the second ring, frame \(index)")
            #expect(exported[index].rednessBeforeCut < 40, "no ring at the first click, frame \(index)")
        }
        for index in exported.indices {
            #expect(exported[index].rednessInsideCut < 40, "no ring from the cut, frame \(index)")
        }
    }

    /// A chip is up for 1.5 s from its key's output frame. The key pressed before the cut shows from
    /// frame 9; the ones cut away and dropped at the pause would darken the same place from frame 21
    /// on, and the key pressed after the pause shows from frame 57.
    private func assertChips(_ exported: [Measured]) {
        for index in 9...40 {
            #expect(exported[index].chip * 2 <= exported[index].level, "the chip, frame \(index)")
        }
        for index in 1...8 {
            #expect(exported[index].chip * 10 >= exported[index].level * 6, "no chip yet, frame \(index)")
        }
        for index in 54...56 {
            #expect(exported[index].chip * 10 >= exported[index].level * 6, "no chip from the cut, frame \(index)")
        }
        for index in 60...74 {
            #expect(exported[index].chip * 2 <= exported[index].level, "the second chip, frame \(index)")
        }
    }

    /// The cursor, drawn from the telemetry: it rests between the clicks, its hot spot is on each
    /// click at the click's own output frame, and it comes back.
    private func assertCursor(_ exported: [Measured]) {
        #expect(exported[0].cursorAtRest, "the cursor at rest, frame 0")
        #expect(exported[15].cursorBeforeCut, "the cursor on the first click, frame 15")
        #expect(exported[30].cursorAfterCut, "the cursor on the second click, frame 30")
        #expect(exported[60].cursorAtRest, "the cursor back at rest, frame 60")
        #expect(!exported[60].cursorBeforeCut && !exported[60].cursorAfterCut, "the cursor away from the clicks, frame 60")
    }

    // MARK: - Measuring

    /// What one exported frame shows where the overlays must be.
    private struct Measured {

        /// The video's grey level where nothing is drawn.
        let level: Int

        /// The largest red-dominance of any pixel within 32 px of a click point: a red ring's stroke
        /// is over 120, while the grey video and the green cursor stay under 40.
        let rednessBeforeCut: Int
        let rednessInsideCut: Int
        let rednessAfterCut: Int

        /// Whether the cursor's green is within 8 px of the point.
        let cursorBeforeCut: Bool
        let cursorAfterCut: Bool
        let cursorAtRest: Bool

        /// The darkest pixel where a key chip is drawn: its dark backing over the video, or the
        /// video's own grey when none is up.
        let chip: Int
    }

    private func measure(_ frame: Frame) -> Measured {
        Measured(
            level: level(of: frame),
            rednessBeforeCut: frame.redness(around: coreImagePoint(clickBeforeCut)),
            rednessInsideCut: frame.redness(around: coreImagePoint(clickInsideCut)),
            rednessAfterCut: frame.redness(around: coreImagePoint(clickAfterCut)),
            cursorBeforeCut: frame.hasGreen(near: coreImagePoint(clickBeforeCut)),
            cursorAfterCut: frame.hasGreen(near: coreImagePoint(clickAfterCut)),
            cursorAtRest: frame.hasGreen(near: coreImagePoint(cursorRest)),
            chip: frame.darkest(in: chipBox)
        )
    }

    /// The recording's frame behind an output frame: the cut's half second is gone from 0.7 s on.
    private func sourceFrame(atOutputFrame index: Int) -> Int {
        let removed = Int(((cut.upperBound - cut.lowerBound) * Double(frameRate)).rounded())
        return index + (index >= cutFrame ? removed : 0)
    }

    /// A frame's grey level, sampled where the overlays are never drawn.
    private func level(of frame: Frame) -> Int {
        frame.luminance(at: CGPoint(x: 300, y: 130))
    }

    /// The screen point as the renderer places it: Core Image space, bottom-left origin. The
    /// telemetry maps 1 px per point across the whole frame here, so the flip is all there is.
    private func coreImagePoint(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(x: screenPoint.x, y: videoSize.height - screenPoint.y)
    }

    // MARK: - Fixtures

    /// A source frame's grey level: a band of 8 frames, 14 levels apart, so a frame's level says
    /// which eighth of a second of the recording it is.
    private func level(ofSourceFrame index: Int) -> UInt8 {
        UInt8(30 + (index / 8) * 14)
    }

    private func store() -> SettingsStore {
        let settings = SettingsStore(defaults: defaults.make())
        settings.frameRate = .fps30
        return settings
    }

    private func hostTime(_ offset: Double) -> CMTime {
        CMTime(seconds: anchor + offset, preferredTimescale: 600)
    }

    /// The telemetry as `InputTelemetryRecorder` keeps it while recording: host-clock seconds,
    /// before the pauses are cut out.
    private var recordedTelemetry: InputTelemetry {
        let screen = CGRect(origin: .zero, size: videoSize)
        var telemetry = InputTelemetry(
            capture: .init(kind: .display, videoSize: videoSize, cursorInVideo: false), keystrokesAvailable: true
        )
        // The whole frame, 1 px per screen point
        telemetry.geometry = [.init(time: anchor, screenRect: screen, contentRect: screen, contentScale: 1, scaleFactor: 1)]
        // The cursor rests on one point for the whole recording
        telemetry.cursor = stride(from: 0.0, through: 4.0, by: 1.0 / 60).map {
            .init(time: anchor + $0, location: cursorRest)
        }
        telemetry.clicks = clicks.map {
            .init(time: anchor + $0.offset, location: $0.location, button: .left, isDown: true, clickCount: 1)
        }
        telemetry.keys = keys.map {
            .init(time: anchor + $0, keyCode: kVK_RightArrow, modifiers: [], isRepeat: false)
        }
        return telemetry
    }

    /// What the editor draws with: the keys named by a known layout's glyphs, and a green square as
    /// the cursor's image, so frames can be read for it.
    private var resources: RenderResources {
        RenderResources(keyLabels: KeyLabelFormatter.layout(id: "com.apple.keylayout.US"), arrow: greenSquare)
    }

    private var greenSquare: InputTelemetry.CursorSprite {
        .drawn(pixels: CGSize(width: 8, height: 8), size: CGSize(width: 4, height: 4)) {
            $0.setFillColor(red: 0, green: 1, blue: 0, alpha: 1)
            $0.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    /// An opaque grey frame at `index` of the recording, `level` in every channel, at the host-clock
    /// second that frame was captured at, marked complete as the capture engine delivers it.
    private func videoFrame(level: UInt8, at index: Int) throws -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, Int(videoSize.width), Int(videoSize.height), kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary] as CFDictionary, &pixelBuffer
        )
        #expect(status == kCVReturnSuccess)
        let imageBuffer = try #require(pixelBuffer)
        CVPixelBufferLockBaseAddress(imageBuffer, [])
        memset(CVPixelBufferGetBaseAddress(imageBuffer), Int32(level), CVPixelBufferGetDataSize(imageBuffer))
        CVPixelBufferUnlockBaseAddress(imageBuffer, [])

        var formatDescription: CMFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault, imageBuffer: imageBuffer, formatDescriptionOut: &formatDescription
        )
        #expect(formatStatus == noErr)
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(frameRate)),
            presentationTimeStamp: CMTime(value: CMTimeValue(index) + CMTimeValue(anchor * Double(frameRate)), timescale: CMTimeScale(frameRate)),
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let createStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault, imageBuffer: imageBuffer,
            formatDescription: try #require(formatDescription), sampleTiming: &timing, sampleBufferOut: &sampleBuffer
        )
        #expect(createStatus == noErr)
        let buffer = try #require(sampleBuffer)

        // appendVideoSample only accepts frames the capture engine marked complete
        let attachments = try #require(
            CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true) as? [NSMutableDictionary]
        )
        try #require(attachments.first)[SCStreamFrameInfo.status.rawValue] = SCFrameStatus.complete.rawValue
        return buffer
    }

    /// Every frame of a video file in presentation order, decoded to 8-bit BGRA.
    ///
    /// Sorted by presentation time: the encoder reorders its frames, so the reader can hand them back
    /// in decode order (as `AssetWriterTests.videoPresentationTimes` notes).
    private func frames(of url: URL) async throws -> [Frame] {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        reader.add(output)
        #expect(reader.startReading())

        var frames: [Frame] = []
        while let sample = output.copyNextSampleBuffer(), let buffer = sample.imageBuffer {
            let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            CVPixelBufferLockBaseAddress(buffer, .readOnly)
            let width = CVPixelBufferGetWidth(buffer)
            let height = CVPixelBufferGetHeight(buffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            let base = try #require(CVPixelBufferGetBaseAddress(buffer)).assumingMemoryBound(to: UInt8.self)
            let pixels = Array(UnsafeBufferPointer(start: base, count: bytesPerRow * height))
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
            frames.append(Frame(time: time, pixels: pixels, bytesPerRow: bytesPerRow, width: width, height: height))
        }
        #expect(reader.status == .completed)
        return frames.sorted { $0.time < $1.time }
    }

    /// One decoded frame's pixels, read by Core Image-style points so they can be compared with what
    /// `FrameRenderer` draws.
    private struct Frame {
        let time: Double
        let pixels: [UInt8]
        let bytesPerRow: Int
        let width: Int
        let height: Int

        /// The pixel whose bottom-left corner is at `point`, in Core Image space (the frame's rows
        /// run downwards from the top; its y from the bottom).
        func value(at point: CGPoint) -> Channels {
            let column = min(max(Int(point.x), 0), width - 1)
            let row = min(max(height - 1 - Int(point.y), 0), height - 1)
            let offset = row * bytesPerRow + column * 4
            return Channels(red: Int(pixels[offset + 2]), green: Int(pixels[offset + 1]), blue: Int(pixels[offset]))
        }

        func luminance(at point: CGPoint) -> Int {
            let value = value(at: point)
            return (value.red + value.green + value.blue) / 3
        }

        /// The largest red-dominance of any pixel within `radius` of `point`.
        func redness(around point: CGPoint, radius: Int = 32) -> Int {
            var maximum = Int.min
            for row in (Int(point.y) - radius)...(Int(point.y) + radius) {
                for column in (Int(point.x) - radius)...(Int(point.x) + radius) {
                    let value = value(at: CGPoint(x: Double(column), y: Double(row)))
                    maximum = max(maximum, value.red - value.blue)
                }
            }
            return maximum
        }

        /// Whether the cursor's green is within `radius` of `point`.
        func hasGreen(near point: CGPoint, radius: Int = 8) -> Bool {
            for row in (Int(point.y) - radius)...(Int(point.y) + radius) {
                for column in (Int(point.x) - radius)...(Int(point.x) + radius) {
                    let value = value(at: CGPoint(x: Double(column), y: Double(row)))
                    if value.green > 180, value.red < 120, value.blue < 120 { return true }
                }
            }
            return false
        }

        /// The darkest pixel in `box`, a rectangle in Core Image space.
        func darkest(in box: CGRect) -> Int {
            var minimum = Int.max
            for row in Int(box.minY)...Int(box.maxY) {
                for column in Int(box.minX)...Int(box.maxX) {
                    minimum = min(minimum, luminance(at: CGPoint(x: Double(column), y: Double(row))))
                }
            }
            return minimum
        }
    }

    /// One pixel's channels, 0 to 255.
    private struct Channels {
        let red: Int
        let green: Int
        let blue: Int
    }
}
