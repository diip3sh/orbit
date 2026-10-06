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

        let segment = try #require(WebCamera.segments(for: script, telemetry: cursor, shots: []).first)

        #expect(segment.range == 1.6..<3.6)
        #expect(segment.scale == 3)
        #expect(!segment.isAutomatic)
        // 360 of a 1440-wide viewport is a quarter, moved in so a 3× view stays inside the frame
        #expect(segment.fixedCenter == CGPoint(x: 0.25, y: 0.5))
    }

    @Test func withoutCursorSamplesTheTargetsPointIsUsed() throws {
        let script = script([clip(2..<3, zoom: 1.5, at: CGPoint(x: 1080, y: 225))])

        let segment = try #require(WebCamera.segments(for: script, telemetry: telemetry(cursor: []), shots: []).first)

        #expect(segment.fixedCenter == CGPoint(x: 0.6666666666666667, y: 1.0 / 3.0))
    }

    @Test func zoomsThatMeetHandOverSoTheViewPans() {
        let script = script([clip(2..<3, zoom: 2), clip(3.5..<4.5, zoom: 2)])

        let segments = WebCamera.segments(for: script, telemetry: telemetry(cursor: []), shots: [])

        #expect(segments.map(\.range) == [1.6..<3.1, 3.1..<5.1])
    }

    @Test func unzoomedClipsGiveNoSegments() {
        #expect(WebCamera.segments(for: script([clip(2..<3, zoom: nil)]), telemetry: telemetry(cursor: []), shots: []).isEmpty)
    }

    @Test func scriptsSavedBeforeZoomsStillLoad() throws {
        let saved = Data(##"{"id":"6F1C2A10-6C1B-4E3B-9A11-2D3C4B5A6F70","range":[1,2],"action":"hover","target":{"selector":"#a","anchor":[0.5,0.5],"point":[10,20]}}"##.utf8)

        let clip = try JSONDecoder().decode(PointerClip.self, from: saved)

        #expect(clip.zoom == nil)
        #expect(clip.action == .hover)
    }

    // MARK: - Showing elements

    private let viewport = CGSize(width: 1440, height: 900)

    private func shot(_ range: Range<Double>, _ visible: CGRect = CGRect(x: 100, y: 100, width: 480, height: 300)) -> WebCamera.Shot {
        WebCamera.Shot(range: range, visible: visible)
    }

    @Test func anElementFillsAtMostEightyPercentOfTheView() throws {
        // 480 × 300 of 1440 × 900: 0.8 × 3 = 2.4 either way
        let fit = try #require(WebCamera.fit(CGRect(x: 0, y: 0, width: 480, height: 300), in: viewport))

        #expect(abs(fit.scale - 2.4) < 1e-9)
        // Its middle, a sixth of the way in, moved in so the 2.4× view stays inside the frame
        #expect(abs(fit.center.x - 0.5 / 2.4) < 1e-9)
        #expect(abs(fit.center.y - 0.5 / 2.4) < 1e-9)
    }

    @Test func aSmallElementIsMagnifiedAtMostThreeTimes() throws {
        let fit = try #require(WebCamera.fit(CGRect(x: 700, y: 400, width: 40, height: 20), in: viewport))

        #expect(fit.scale == 3)
        #expect(fit.center == CGPoint(x: 0.5, y: 0.45555555555555555))
    }

    @Test func anElementNearlyTheWholeViewIsntZoomedOn() {
        // A full-width hero: 0.8 × 1440 / 1400 is under 1.1
        #expect(WebCamera.fit(CGRect(x: 20, y: 0, width: 1400, height: 600), in: viewport) == nil)
        #expect(WebCamera.fit(CGRect(x: 20, y: 0, width: 0, height: 600), in: viewport) == nil)
    }

    @Test func onlyAnElementMostlyInViewIsFramed() {
        let viewport = CGSize(width: 1000, height: 1000)

        // Under half of it in view, then half
        #expect(WebCamera.visiblePart(of: CGRect(x: 0, y: 901, width: 100, height: 200), in: viewport) == nil)
        #expect(WebCamera.visiblePart(of: CGRect(x: 0, y: 900, width: 100, height: 200), in: viewport) == CGRect(x: 0, y: 900, width: 100, height: 100))
        #expect(WebCamera.visiblePart(of: CGRect(x: -50, y: 0, width: 100, height: 100), in: viewport) == CGRect(x: 0, y: 0, width: 50, height: 100))
        #expect(WebCamera.visiblePart(of: CGRect(x: 2000, y: 0, width: 100, height: 100), in: viewport) == nil)
    }

    @Test func aShownElementZoomsForItsStep() throws {
        let zoom = try #require(WebCamera.showSegments([shot(2..<4.5)], viewport: viewport, pageChanges: []).first)

        #expect(zoom.range == 2..<4.5)
        #expect(abs(zoom.scale - 2.4) < 1e-9)
        #expect(!zoom.isAutomatic)
    }

    @Test func zoomsUnderASecondApartPanAcross() {
        let zooms = WebCamera.showSegments([shot(1..<2.5), shot(3.3..<4.8), shot(6..<7.5)], viewport: viewport, pageChanges: [])

        #expect(zooms.map(\.range) == [1..<3.3, 3.3..<4.8, 6..<7.5])
    }

    @Test func aZoomEndsSoonAfterThePageStartsToChange() {
        // A scroll into view starts as the first ends, so the camera is out before the page moves far
        let zooms = WebCamera.showSegments([shot(1..<2.5), shot(3.3..<4.8)], viewport: viewport, pageChanges: [2.5])

        #expect(zooms.map(\.range) == [1..<2.8, 3.3..<4.8])
    }

    @Test func aZoomThePageChangesUnderAtOnceIsDropped() {
        // A click that opens a page: the camera would zoom in and straight back out
        #expect(WebCamera.showSegments([shot(1..<2.5)], viewport: viewport, pageChanges: [1.02]).isEmpty)
    }

    @Test func onceAStepShowsAnElementOnlyShownElementsZoom() {
        var shown = clip(4..<5.5, zoom: nil)
        shown.show = "#shot"
        let script = script([clip(1..<2, zoom: 2), shown])

        let segments = WebCamera.segments(for: script, telemetry: telemetry(cursor: []), shots: [shot(4..<5.5)])

        #expect(segments.map(\.range) == [4..<5.5])
        #expect(WebCamera.zooms(on: script.pointer[0], in: script) == false)
        #expect(WebCamera.zooms(on: script.pointer[1], in: script))
        #expect(WebCamera.shownClip(at: 4.5, in: script)?.id == shown.id)
        #expect(WebCamera.shownClip(at: 3, in: script) == nil)
    }

    @Test func aScriptThatShowsElementsButFoundNoneHasNoZooms() {
        var shown = clip(4..<5.5, zoom: nil)
        shown.show = "#gone"

        #expect(WebCamera.segments(for: script([clip(1..<2, zoom: 2), shown]), telemetry: telemetry(cursor: []), shots: []).isEmpty)
    }
}
