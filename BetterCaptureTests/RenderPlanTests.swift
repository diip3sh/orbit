//
//  RenderPlanTests.swift
//  BetterCaptureTests
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation
import Carbon.HIToolbox
import CoreImage
import Testing
@testable import BetterCapture

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

    private func source(telemetry: InputTelemetry?) -> EditorSource {
        EditorSource(
            asset: AVURLAsset(url: URL(filePath: "/dev/null")),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)),
            videoTrackID: 1,
            audioTrackIDs: [],
            naturalSize: CGSize(width: 1600, height: 1200),
            frameRate: 60,
            timescale: 600,
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

        let plan = await RenderPlan.build(project: project, source: source(telemetry: nil), keyLabels: nil)

        #expect(plan.camera.viewport(at: 0) == .whole)
        #expect(plan.camera.viewport(at: 5).scale > 1.99)
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

        let plan = await RenderPlan.build(project: project, source: source(telemetry: telemetry), keyLabels: KeyLabelFormatter.current())

        #expect(plan.clicks.isEmpty)
        #expect(plan.keystrokes.isEmpty)
        #expect(plan.timeMap.outputDuration == 9)
    }

    @Test func buildsNoOverlaysWithoutTelemetry() async {
        let plan = await RenderPlan.build(project: EditorProject(), source: source(telemetry: nil), keyLabels: KeyLabelFormatter.current())

        #expect(plan.clicks.isEmpty)
        #expect(plan.keystrokes.isEmpty)
        #expect(plan.videoSize == CGSize(width: 1600, height: 1200))
    }

    @Test func buildsOneChipImagePerLabel() async {
        let plan = await RenderPlan.build(
            project: EditorProject(), source: source(telemetry: telemetry), keyLabels: KeyLabelFormatter.layout(id: "com.apple.keylayout.US")
        )

        #expect(plan.clicks.count == 3)
        #expect(plan.clickRing.extent.width == 88)
        #expect(plan.chipImages.count == 2)
        // 6% of the video's shorter side
        #expect(plan.chipImages.allSatisfy { $0.extent.height == 72 })
    }
}
