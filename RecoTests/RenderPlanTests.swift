//
//  RenderPlanTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation
import Carbon.HIToolbox
import CoreImage
import Testing
@testable import Reco

@MainActor
struct RenderPlanTests {

    /// A 800×600 pt window at (100, 80) on a 2× display, recorded at 1600×1200 px. It moves 100 pt
    /// to the right at 5 s.
    private var telemetry: InputTelemetry {
        var telemetry = InputTelemetry(capture: .init(kind: .window, videoSize: CGSize(width: 1600, height: 1200)), keystrokesAvailable: true)
        let geometry = InputTelemetry.Geometry(
            time: 0,
            screenRect: CGRect(x: 100, y: 80, width: 800, height: 600),
            contentRect: CGRect(x: 0, y: 0, width: 800, height: 600),
            contentScale: 1,
            scaleFactor: 2
        )
        var moved = geometry
        moved.time = 5
        moved.screenRect.origin.x = 200
        telemetry.geometry = [geometry, moved]
        telemetry.clicks = [
            .init(time: 1, location: CGPoint(x: 300, y: 200), button: .left, isDown: true, clickCount: 1),
            .init(time: 1.1, location: CGPoint(x: 300, y: 200), button: .left, isDown: false, clickCount: 1),
            .init(time: 2, location: CGPoint(x: 300, y: 200), button: .right, isDown: true, clickCount: 1),
            .init(time: 6, location: CGPoint(x: 300, y: 200), button: .left, isDown: true, clickCount: 1)
        ]
        telemetry.keys = [
            .init(time: 1, keyCode: kVK_ANSI_C, modifiers: ["command"], isRepeat: false),
            .init(time: 2, keyCode: kVK_ANSI_A, modifiers: [], isRepeat: false),
            .init(time: 3, keyCode: kVK_ANSI_V, modifiers: ["command"], isRepeat: false),
            .init(time: 3.5, keyCode: kVK_ANSI_V, modifiers: ["command"], isRepeat: true),
            .init(time: 4, keyCode: kVK_ANSI_C, modifiers: ["command"], isRepeat: false)
        ]
        return telemetry
    }

    private func source(telemetry: InputTelemetry?, dynamicRange: DynamicRange = .sdr) -> EditorSource {
        EditorSource(
            asset: AVURLAsset(url: URL(filePath: "/dev/null")),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)),
            videoTrackID: 1,
            audioTrackIDs: [],
            naturalSize: CGSize(width: 1600, height: 1200),
            frameRate: 60,
            timescale: 600,
            dynamicRange: dynamicRange,
            telemetry: telemetry,
            telemetryError: nil
        )
    }

    @Test func flipsVideoPixelsIntoCoreImageSpace() {
        #expect(RenderPlan.coreImagePoint(CGPoint(x: 400, y: 240), videoHeight: 1200) == CGPoint(x: 400, y: 960))
    }

    @Test func placesClicksWithTheGeometryInEffectAtTheirTime() {
        let markers = RenderPlan.clickMarkers(for: telemetry, style: ClickHighlightStyle(), videoHeight: 1200)

        #expect(markers.map(\.time) == [1, 2, 6])
        // (300 - 100) × 2 = 400 px from the left, (200 - 80) × 2 = 240 px from the top
        #expect(markers[0].position == CGPoint(x: 400, y: 960))
        // After the window moved 100 pt right, the same screen point is 200 px further left in it
        #expect(markers[2].position == CGPoint(x: 200, y: 960))
        #expect(markers[0].diameter == 88)
    }

    @Test func placesCursorPositionsWhileAZoomFollowsItWithTheGeometryInEffect() {
        var telemetry = telemetry
        telemetry.cursor = [1, 3, 6, 9].map { InputTelemetry.CursorSample(time: $0, location: CGPoint(x: 500, y: 380)) }
        let zooms = [
            ZoomSegment(range: 4..<7, focus: .followCursor),
            ZoomSegment(range: 8..<10, focus: .fixed(center: CGPoint(x: 0.5, y: 0.5)))
        ]

        let points = RenderPlan.cursorPoints(for: telemetry, during: zooms)

        // From the position at the zoom's start
        #expect(points.map(\.time) == [3, 6])
        // 800 of 1600 px from the left and 600 of 1200 from the top; after the move, 600 px from the left
        #expect(points.map(\.point) == [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.375, y: 0.5)])
    }

    @Test func aCropIsTheVideoForEverythingInThePlan() async {
        var project = EditorProject()
        project.crop = CGRect(x: 0.25, y: 0, width: 0.5, height: 0.5)

        let plan = await RenderPlan.build(project: project, source: source(telemetry: telemetry), resources: .none)

        // 400…1200 px across and the top 600 px, which is 600…1200 in Core Image's space
        #expect(plan.videoSize == CGSize(width: 800, height: 600))
        #expect(plan.crop == CGRect(x: 400, y: 600, width: 800, height: 600))
        // The first click is 400 px from the left and 240 from the top of the video: the crop's left edge
        #expect(plan.clicks.first?.position == CGPoint(x: 0, y: 360))
    }

    @Test func aCroppedFrameShowsOnlyTheCrop() async throws {
        var project = EditorProject()
        project.canvas = .plain
        project.crop = CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        let plan = await RenderPlan.build(project: project, source: source(telemetry: nil), resources: .none)
        // Red on the left half, blue on the right
        let frame = CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 1600, height: 1200))
        let left = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 800, height: 1200))

        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            nil, Int(plan.canvas.size.width), Int(plan.canvas.size.height), kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer
        )
        let output = try #require(buffer)
        try FrameRenderer.draw(
            left.composited(over: frame), at: 1, plan: plan, into: output,
            context: CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])
        )

        #expect(plan.canvas.size == CGSize(width: 800, height: 1200))
        let image = CIImage(cvPixelBuffer: output)
        #expect(image.pixel(at: CGPoint(x: 0, y: 0)) == [0, 0, 255, 255])
        #expect(image.pixel(at: CGPoint(x: 799, y: 1199)) == [0, 0, 255, 255])
    }

    @Test func buildsTheCameraFromTheZooms() async {
        let project = EditorProject(zooms: [ZoomSegment(range: 1..<9, focus: .fixed(center: CGPoint(x: 0.25, y: 0.25)))])

        let plan = await RenderPlan.build(project: project, source: source(telemetry: nil), resources: .none)

        #expect(plan.camera.viewport(at: 0) == .whole)
        #expect(plan.camera.viewport(at: 5).scale > 1.99)
    }

    @Test func drawsTheCursorOnlyWhenTheVideoHasNone() async {
        var telemetry = telemetry
        telemetry.cursor = [.init(time: 0, location: CGPoint(x: 500, y: 380))]
        var project = EditorProject()
        let arrow = StandardCursors.arrowSprite

        let withCursor = await RenderPlan.build(project: project, source: source(telemetry: telemetry), resources: RenderResources(arrow: arrow))
        #expect(withCursor.cursor == nil)

        telemetry.capture.cursorInVideo = false
        let withoutCursor = await RenderPlan.build(project: project, source: source(telemetry: telemetry), resources: RenderResources(arrow: arrow))
        // 800 px from the left and 600 from the top, of 1200, before gliding onto the click at 1 s
        #expect(withoutCursor.cursor?.position(at: 0.3) == CGPoint(x: 800, y: 600))
        #expect(withoutCursor.cursorShapes.sprite(at: 1) != nil)

        project.cursor.isEnabled = false
        let hidden = await RenderPlan.build(project: project, source: source(telemetry: telemetry), resources: RenderResources(arrow: arrow))
        #expect(hidden.cursor == nil)
        #expect(hidden.cursorShapes.sprite(at: 1) == nil)
    }

    @Test func highlightsOnlyTheChosenButton() {
        var style = ClickHighlightStyle()
        style.buttons = .right

        #expect(RenderPlan.clickMarkers(for: telemetry, style: style, videoHeight: 1200).map(\.time) == [2])
    }

    @Test func showsShortcutsOnceEachLabelAndNotRepeats() throws {
        let keyLabels = try #require(KeyLabelFormatter.layout(id: "com.apple.keylayout.US"))

        let (chips, labels) = RenderPlan.keystrokeChips(for: telemetry, style: KeystrokeOverlayStyle(), keyLabels: keyLabels)

        #expect(labels == ["⌘C", "⌘V"])
        #expect(chips == [KeystrokeChip(time: 1, image: 0), KeystrokeChip(time: 3, image: 1), KeystrokeChip(time: 4, image: 0)])
    }

    @Test func buildsNoOverlaysWhenTheyAreOff() async {
        var project = EditorProject(cuts: [2..<3])
        project.clickHighlights.effect = .off
        project.keystrokes.isEnabled = false

        let plan = await RenderPlan.build(project: project, source: source(telemetry: telemetry), resources: RenderResources(keyLabels: KeyLabelFormatter.current()))

        #expect(plan.clicks.isEmpty)
        #expect(plan.keystrokes.isEmpty)
        #expect(plan.timeMap.outputDuration == 9)
    }

    @Test func timesOverlaysAndTheCameraOnTheOutput() async {
        // Kept: 0..<1.5, 2.5..<4, then 4..<8 at 2× and 8..<10: 7 s of output
        var project = EditorProject(cuts: [1.5..<2.5])
        project.speeds = [SpeedRange(range: 4..<8, rate: 2)]
        project.zooms = [ZoomSegment(range: 4..<8, focus: .fixed(center: CGPoint(x: 0.5, y: 0.5)))]
        let resources = RenderResources(keyLabels: KeyLabelFormatter.layout(id: "com.apple.keylayout.US"))

        let plan = await RenderPlan.build(project: project, source: source(telemetry: telemetry), resources: resources)

        #expect(plan.timeMap.outputDuration == 7)
        // The click at 2 s is cut; the one at 6 s is 2 s into the 2× part
        #expect(plan.clicks.map(\.time) == [1, 4])
        #expect(plan.keystrokes.map(\.time) == [1, 2, 3])
        // The zoom spans output 3..<5
        #expect(plan.camera.viewport(at: 2.9) == .whole)
        #expect(plan.camera.viewport(at: 4.9).scale > 1.9)
    }

    @Test func buildsNoOverlaysWithoutTelemetry() async {
        let plan = await RenderPlan.build(project: EditorProject(), source: source(telemetry: nil), resources: RenderResources(keyLabels: KeyLabelFormatter.current()))

        #expect(plan.clicks.isEmpty)
        #expect(plan.keystrokes.isEmpty)
        #expect(plan.videoSize == CGSize(width: 1600, height: 1200))
    }

    @Test func buildsTheCanvasAtTheTargetsSize() async {
        // The video's own 4:3, so the frame keeps its size; Original would grow by the padding
        var project = EditorProject()
        project.canvas.aspect = .standard
        let preview = await RenderPlan.build(project: project, source: source(telemetry: nil), resources: .none)
        let export = await RenderPlan.build(project: project, source: source(telemetry: nil), resources: .none, target: RenderTarget(shorterSide: 600))

        #expect(preview.canvas.size == CGSize(width: 1600, height: 1200))
        #expect(export.canvas.size == CGSize(width: 800, height: 600))
        #expect(export.canvas.videoFrame.height == 504)
    }

    @Test func buildsOneChipImagePerLabel() async {
        let plan = await RenderPlan.build(
            project: EditorProject(), source: source(telemetry: telemetry), resources: RenderResources(keyLabels: KeyLabelFormatter.layout(id: "com.apple.keylayout.US"))
        )

        #expect(plan.clicks.count == 3)
        #expect(plan.clickRing.extent.width == 88)
        #expect(plan.chipImages.count == 2)
        // 6% of the shorter side of the video on the canvas: 1,200 px less 8% padding at the top and bottom
        #expect(plan.canvas.videoFrame.height == 1008)
        #expect(plan.chipImages.allSatisfy { $0.extent.height == 61 })
    }

    @Test func drawsHDROverlaysInTheRecordingsEncodingAtSDRWhite() async {
        let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
        var project = EditorProject()
        project.clickHighlights.color = white
        project.canvas.background = .color
        project.canvas.color = white
        var telemetry = telemetry
        telemetry.capture.cursorInVideo = false
        telemetry.cursor = [.init(time: 0, location: CGPoint(x: 500, y: 380))]
        let resources = RenderResources(keyLabels: KeyLabelFormatter.layout(id: "com.apple.keylayout.US"), arrow: StandardCursors.arrowSprite)
        let source = source(telemetry: telemetry, dynamicRange: .pq)

        let hdr = await RenderPlan.build(project: project, source: source, resources: resources)
        let sdr = await RenderPlan.build(project: project, source: source, resources: resources, target: RenderTarget(keepsHDR: false))

        #expect(hdr.dynamicRange == .pq && sdr.dynamicRange == .sdr)
        // SDR white is 203 nits in PQ, BT.2408's reference white
        for (plan, white) in [(hdr, Float(0.58)), (sdr, 1)] {
            let images = [plan.clickRing, plan.chipImages.first, plan.canvas.backdrop, plan.cursorShapes.sprite(at: 1)?.image]
            #expect(images.allSatisfy { $0.map { abs($0.brightestRed - white) < 0.001 } ?? false })
        }
    }

    @Test func theCursorLoopEndsAtTheLastFrameShown() {
        // The last kept frame is the one before 9 s
        let loop = RenderPlan.cursorLoop(for: TimeMap(cuts: [9..<10], sourceDuration: 10, frameRate: 60))

        #expect(loop.start == 0)
        #expect(abs(loop.glide.upperBound - 539.0 / 60) < 1e-9)
        #expect(abs(loop.glide.lowerBound - (539.0 / 60 - CursorPath.loopDuration)) < 1e-9)
    }

    @Test func theCursorLoopStaysInsideTheLastKeptRange() {
        // Kept: 0..<1 and a last range of 0.4 s, shorter than the glide
        let loop = RenderPlan.cursorLoop(for: TimeMap(cuts: [1..<9.6], sourceDuration: 10, frameRate: 60))

        #expect(abs(loop.glide.lowerBound - 9.6) < 1e-9)
        #expect(abs(loop.glide.upperBound - (10 - 1.0 / 60)) < 1e-9)
    }

    @Test func theCursorStopsItsDurationOfOutputBeforeTheLastFrame() throws {
        // Source 2..<4 is cut, so the last frame at 599/60 of source is 479/60 of output
        let timeMap = TimeMap(cuts: [2..<4], sourceDuration: 10, frameRate: 60)

        #expect(RenderPlan.cursorStop(before: 0, for: timeMap) == nil)
        let stop = try #require(RenderPlan.cursorStop(before: 3, for: timeMap))
        // 479/60 - 3 of output is past the cut, so 2 s later in source
        #expect(abs(stop - (479.0 / 60 - 3 + 2)) < 1e-9)
        // Longer than the video, it holds from the first frame
        #expect(RenderPlan.cursorStop(before: 20, for: timeMap) == 0)
    }

    @Test func buildsALoopingCursorOnlyWhenAsked() async {
        var telemetry = telemetry
        telemetry.capture.cursorInVideo = false
        telemetry.cursor = (0...600).map { InputTelemetry.CursorSample(time: Double($0) / 60, location: CGPoint(x: 300 + Double($0) / 3, y: 380)) }
        var project = EditorProject()
        project.cursor.animatesClicks = false

        let plain = await RenderPlan.build(project: project, source: source(telemetry: telemetry), resources: .none)
        project.cursor.loops = true
        let looping = await RenderPlan.build(project: project, source: source(telemetry: telemetry), resources: .none)

        #expect(plain.cursor?.position(at: 9.9) != plain.cursor?.position(at: 0))
        #expect(looping.cursor?.position(at: 10 - 1.0 / 60) == looping.cursor?.position(at: 0))
    }

    @Test func buildsTheChosenCursorImages() async {
        var telemetry = telemetry
        telemetry.capture.cursorInVideo = false
        telemetry.cursor = [.init(time: 0, location: CGPoint(x: 500, y: 380))]
        var project = EditorProject()

        project.cursor.appearance = .dot
        let dot = await RenderPlan.build(project: project, source: source(telemetry: telemetry), resources: .none)
        project.cursor.appearance = .white
        let white = await RenderPlan.build(project: project, source: source(telemetry: telemetry), resources: .none)

        // Drawn once at 8 pixels per point
        #expect(dot.cursorShapes.sprite(at: 5)?.image.extent.size == CGSize(width: 128, height: 128))
        #expect(dot.cursorShapes.sprite(at: 5)?.pointsPerPixel == 1.0 / 8)
        #expect(white.cursorShapes.sprite(at: 5)?.pointsPerPixel == 1.0 / 8)
        #expect(white.cursorShapes.sprite(at: 5)?.image.extent.width != 128)
    }
}
