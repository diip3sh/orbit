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
        project.clickHighlights.isEnabled = false
        project.keystrokes.isEnabled = false

        let plan = await RenderPlan.build(project: project, source: source(telemetry: telemetry), resources: RenderResources(keyLabels: KeyLabelFormatter.current()))

        #expect(plan.clicks.isEmpty)
        #expect(plan.keystrokes.isEmpty)
        #expect(plan.timeMap.outputDuration == 9)
    }

    @Test func buildsNoOverlaysWithoutTelemetry() async {
        let plan = await RenderPlan.build(project: EditorProject(), source: source(telemetry: nil), resources: RenderResources(keyLabels: KeyLabelFormatter.current()))

        #expect(plan.clicks.isEmpty)
        #expect(plan.keystrokes.isEmpty)
        #expect(plan.videoSize == CGSize(width: 1600, height: 1200))
    }

    @Test func buildsTheCanvasAtTheTargetsSize() async {
        let preview = await RenderPlan.build(project: EditorProject(), source: source(telemetry: nil), resources: .none)
        let export = await RenderPlan.build(project: EditorProject(), source: source(telemetry: nil), resources: .none, target: RenderTarget(shorterSide: 600))

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
}
