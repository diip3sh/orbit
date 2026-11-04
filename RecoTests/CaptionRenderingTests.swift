//
//  CaptionRenderingTests.swift
//  RecoTests
//

import CoreImage
import CoreVideo
import Testing
@testable import Reco

// MARK: - Rendering

struct CaptionRenderingTests {

    private static let highlight = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
    private static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])

    /// A 4 s, 30 fps, 1280×720 grey recording.
    private func source() async throws -> EditorSource {
        let url = try temporaryFolder().appending(path: "video.mov")
        try await TestRecording.write(to: url, size: CGSize(width: 1280, height: 720), frameCount: 120, frameRate: 30) { _ in 128 }
        return try await EditorSourceLoader.load(videoURL: url)
    }

    private func project(_ cues: [CaptionCue]) -> EditorProject {
        var project = EditorProject()
        project.captions.cues = cues
        project.captions.style.highlightColor = Self.highlight
        return project
    }

    /// The BGRA bytes of the frame at output time `time`, a grey frame underneath.
    private func frame(at time: Double, plan: RenderPlan) throws -> BGRAFrame {
        let size = plan.canvas.size
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        let output = try #require(buffer)
        let grey = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(origin: .zero, size: plan.videoSize))
        try FrameRenderer.draw(grey, at: time, plan: plan, into: output, context: Self.context)
        return BGRAFrame(buffer: output)
    }

    @Test func aCuesPixelsAppearOnlyWhileItShows() async throws {
        let source = try await source()
        let plan = await RenderPlan.build(project: project([cue("hello big world", from: 1)]), source: source, resources: .none)
        let caption = try #require(plan.captions.captions.first)
        let box = caption.mask.extent

        let showing = try frame(at: 1.5, plan: plan)
        // White text, the word being said in the highlight, and a darker box
        #expect(showing.count(in: box) { $0.isWhite } > 100)
        #expect(showing.count(in: box) { $0.isHighlight } > 50)
        let inBox = showing.pixel(at: CGPoint(x: box.minX + 3, y: box.midY))
        #expect(inBox.red < 100)

        let before = try frame(at: 0.5, plan: plan)
        #expect(before.count(in: box) { $0.isWhite } == 0)
        #expect(before.count(in: box) { $0.isHighlight } == 0)
    }

    @Test func theHighlightFollowsTheWord() async throws {
        let source = try await source()
        let plan = await RenderPlan.build(project: project([cue("hello big world", from: 1)]), source: source, resources: .none)
        let caption = try #require(plan.captions.captions.first)
        #expect(caption.words.count == 3)

        let atFirst = try frame(at: 1.5, plan: plan)
        #expect(atFirst.count(in: caption.words[0].rect) { $0.isHighlight } > 20)
        #expect(atFirst.count(in: caption.words[1].rect) { $0.isHighlight } == 0)
        #expect(atFirst.count(in: caption.words[1].rect) { $0.isWhite } > 20)

        let atSecond = try frame(at: 2.5, plan: plan)
        #expect(atSecond.count(in: caption.words[0].rect) { $0.isHighlight } == 0)
        #expect(atSecond.count(in: caption.words[1].rect) { $0.isHighlight } > 20)
    }

    @Test func withoutHighlightingEveryWordIsTheTextColor() async throws {
        let source = try await source()
        var project = project([cue("hello big world", from: 1)])
        project.captions.style.highlightsWords = false
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let caption = try #require(plan.captions.captions.first)
        #expect(try frame(at: 1.5, plan: plan).count(in: caption.mask.extent) { $0.isHighlight } == 0)
    }

    @Test func offDrawsNothing() async throws {
        let source = try await source()
        var project = project([cue("hello", from: 1)])
        project.captions.isEnabled = false
        #expect(await RenderPlan.build(project: project, source: source, resources: .none).captions.captions.isEmpty)
    }

    @Test func aCueEntirelyCutIsNotDrawnAndAPartlyCutOneHidesInTheCut() async throws {
        let source = try await source()
        var project = project([cue("gone", from: 0), cue("one two", from: 2)])
        // The first is cut whole, and the second's first word
        project.cuts = [0..<1, 2..<3]
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let caption = try #require(plan.captions.captions.first)
        #expect(plan.captions.captions.count == 1)
        #expect(caption.range == 2..<4)

        // Output 0.5 is source 1.5, before it; output 1.5 is source 3.5, in its kept part
        #expect(try frame(at: 0.5, plan: plan).count(in: caption.mask.extent) { $0.isWhite } == 0)
        let shown = try frame(at: 1.5, plan: plan)
        #expect(shown.count(in: caption.words[1].rect) { $0.isHighlight } > 10)
        #expect(shown.count(in: caption.words[0].rect) { $0.isHighlight } == 0)
    }

    @Test func aSpeedChangeKeepsACueOnItsContent() async throws {
        let source = try await source()
        var project = project([cue("fast", from: 2)])
        project.speeds = [SpeedRange(range: 2..<4, rate: 2)]
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let caption = try #require(plan.captions.captions.first)
        // Output 2.25 is source 2.5, inside; output 1.9 is source 1.9, before it
        #expect(try frame(at: 2.25, plan: plan).count(in: caption.mask.extent) { $0.isHighlight } > 10)
        #expect(try frame(at: 1.9, plan: plan).count(in: caption.mask.extent) { $0.isHighlight } == 0)
    }

    @Test func theCaptionIsNotZoomed() async throws {
        let source = try await source()
        var project = project([cue("hello", from: 1)])
        project.zooms = [ZoomSegment(range: 0..<4, scale: 2, focus: .fixed(center: CGPoint(x: 0.5, y: 0.5)))]
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let caption = try #require(plan.captions.captions.first)
        // Deep into the zoom, the word still fills its own rect
        #expect(try frame(at: 1.9, plan: plan).count(in: caption.words[0].rect) { $0.isHighlight } > 20)
    }

    @Test func anExportAtAnotherSizeScalesIt() async throws {
        let source = try await source()
        let project = project([cue("hello big world", from: 1)])
        let native = await RenderPlan.build(project: project, source: source, resources: .none)
        let small = await RenderPlan.build(project: project, source: source, resources: .none, target: RenderTarget(shorterSide: 360))
        let (nativeBox, smallBox) = (try #require(native.captions.captions.first).mask.extent, try #require(small.captions.captions.first).mask.extent)
        let ratio = small.canvas.videoFrame.width / native.canvas.videoFrame.width
        #expect(abs(smallBox.width / nativeBox.width - ratio) < 0.05)
    }

    @Test func hdrTextKeepsItsSDRBrightness() async throws {
        let url = try temporaryFolder().appending(path: "hdr.mov")
        try await TestRecording.write(to: url, size: CGSize(width: 1280, height: 720), frameCount: 60, frameRate: 30, hdr: true) { _ in 128 }
        let source = try await EditorSourceLoader.load(videoURL: url)
        var project = project([cue("hello", from: 0)])
        project.captions.style.highlightsWords = false
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        #expect(plan.dynamicRange != .sdr)
        // The white, in PQ: the SDR reference white is about 0.58 of full scale, where 1 would be 10,000 nits
        let white = plan.captions.textColor.cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1)).values(at: .zero)
        #expect(white[0] > 0.4 && white[0] < 0.8)
    }
}

/// A rendered frame's pixels, read in Core Image's bottom-left coordinates.
private struct BGRAFrame {
    struct Pixel {
        let red: UInt8
        let green: UInt8
        let blue: UInt8

        var isWhite: Bool { red > 250 && green > 250 && blue > 250 }
        var isHighlight: Bool { red > 250 && green < 5 && blue < 5 }
    }

    let buffer: CVPixelBuffer

    func pixel(at point: CGPoint) -> Pixel {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let row = CVPixelBufferGetHeight(buffer) - 1 - Int(point.y)
        let bytes = CVPixelBufferGetBaseAddress(buffer)!.advanced(by: row * CVPixelBufferGetBytesPerRow(buffer) + Int(point.x) * 4)
            .assumingMemoryBound(to: UInt8.self)
        return Pixel(red: bytes[2], green: bytes[1], blue: bytes[0])
    }

    func count(in rect: CGRect, where matches: (Pixel) -> Bool) -> Int {
        var count = 0
        for row in Int(rect.minY)..<Int(rect.maxY) {
            for column in Int(rect.minX)..<Int(rect.maxX) where matches(pixel(at: CGPoint(x: column, y: row))) {
                count += 1
            }
        }
        return count
    }
}
