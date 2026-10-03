//
//  WebCameraTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct WebCameraTests {

    private func clip(_ range: Range<Double>, zoom: Double?, at point: CGPoint = CGPoint(x: 720, y: 450)) -> PointerClip {
        PointerClip(range: range, action: .click, target: WebTarget(selector: "#a", point: point), zoom: zoom)
    }

    private func script(_ clips: [PointerClip], duration: Double = 10) -> WebScript {
        var script = WebScript()
        script.duration = duration
        script.pointer = clips
        return script
    }

    private func telemetry(cursor: [(Double, CGPoint)]) -> InputTelemetry {
        var telemetry = InputTelemetry(capture: .init(kind: .web, videoSize: CGSize(width: 2880, height: 1800)), keystrokesAvailable: false)
        telemetry.cursor = cursor.map { .init(time: $0.0, location: $0.1) }
        return telemetry
    }

    @Test func aZoomIsInBeforeItsClipAndOutAfterIt() {
        let zoomed = clip(2..<3, zoom: 2)
        let script = script([clip(0.5..<1, zoom: nil), zoomed])

        #expect(WebCamera.window(of: zoomed, duration: 10) == 1.6..<3.6)
        #expect(WebCamera.zoom(at: 1.7, in: script)?.scale == 2)
        #expect(WebCamera.zoom(at: 3.5, in: script)?.clip.id == zoomed.id)
        #expect(WebCamera.zoom(at: 0.8, in: script) == nil)
        #expect(WebCamera.zoom(at: 3.7, in: script) == nil)
    }

    @Test func theWindowStaysInsideTheTake() {
        #expect(WebCamera.window(of: clip(0.1..<1, zoom: 2), duration: 1.2) == 0..<1.2)
    }

    @Test func theEditorGetsAFixedZoomWhereTheCursorWas() throws {
        let script = script([clip(2..<3, zoom: 3)])
        let cursor = telemetry(cursor: [(0, CGPoint(x: 100, y: 100)), (2.1, CGPoint(x: 360, y: 450))])

        let segment = try #require(WebCamera.segments(for: script, telemetry: cursor).first)

        #expect(segment.range == 1.6..<3.6)
        #expect(segment.scale == 3)
        #expect(!segment.isAutomatic)
        // 360 of a 1440-wide viewport is a quarter, moved in so a 3× view stays inside the frame
        #expect(segment.fixedCenter == CGPoint(x: 0.25, y: 0.5))
    }

    @Test func withoutCursorSamplesTheTargetsPointIsUsed() throws {
        let script = script([clip(2..<3, zoom: 1.5, at: CGPoint(x: 1080, y: 225))])

        let segment = try #require(WebCamera.segments(for: script, telemetry: telemetry(cursor: [])).first)

        #expect(segment.fixedCenter == CGPoint(x: 0.6666666666666667, y: 1.0 / 3.0))
    }

    @Test func zoomsThatMeetHandOverSoTheViewPans() {
        let script = script([clip(2..<3, zoom: 2), clip(3.5..<4.5, zoom: 2)])

        let segments = WebCamera.segments(for: script, telemetry: telemetry(cursor: []))

        #expect(segments.map(\.range) == [1.6..<3.1, 3.1..<5.1])
    }

    @Test func unzoomedClipsGiveNoSegments() {
        #expect(WebCamera.segments(for: script([clip(2..<3, zoom: nil)]), telemetry: telemetry(cursor: [])).isEmpty)
    }

    @Test func scriptsSavedBeforeZoomsStillLoad() throws {
        let saved = Data(##"{"id":"6F1C2A10-6C1B-4E3B-9A11-2D3C4B5A6F70","range":[1,2],"action":"hover","target":{"selector":"#a","anchor":[0.5,0.5],"point":[10,20]}}"##.utf8)

        let clip = try JSONDecoder().decode(PointerClip.self, from: saved)

        #expect(clip.zoom == nil)
        #expect(clip.action == .hover)
    }
}
