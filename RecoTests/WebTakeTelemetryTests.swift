//
//  WebTakeTelemetryTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct WebTakeTelemetryTests {

    private let target = WebTarget(point: CGPoint(x: 10, y: 10))

    @Test func mapsViewportPointsIntoTheVideoByTheScale() throws {
        var script = WebScript()
        script.viewport = CGSize(width: 1280, height: 800)
        let telemetry = WebTakeTelemetry(script: script).telemetry

        #expect(telemetry.capture.kind == .web)
        #expect(telemetry.capture.videoSize == CGSize(width: 2560, height: 1600))
        #expect(!telemetry.capture.cursorInVideo)
        #expect(telemetry.keystrokesAvailable)
        let geometry = try #require(telemetry.geometry(at: 3))
        #expect(InputTelemetry.videoPixel(for: CGPoint(x: 640, y: 100), geometry: geometry) == CGPoint(x: 1280, y: 200))
    }

    @Test func recordsTheCursorWhereItMovedAndClicksWhereItIs() {
        var take = WebTakeTelemetry(script: WebScript())
        let point = CGPoint(x: 5, y: 6)

        take.record(time: 0, cursor: point, presses: [], shape: nil)
        take.record(time: 1 / 60, cursor: point, presses: [.init(time: 0.01, isDown: true, target: target)], shape: nil)
        take.record(time: 2 / 60, cursor: CGPoint(x: 7, y: 6), presses: [.init(time: 0.03, isDown: false, target: target)], shape: nil)

        let telemetry = take.telemetry
        // Typed out: Xcode 26.6, which the release workflow builds with, times out on arithmetic inside #expect
        let frames: [Double] = [1.0 / 60, 2.0 / 60]
        #expect(telemetry.cursor.map(\.time) == [0, frames[1]])
        #expect(telemetry.clicks.map(\.isDown) == [true, false])
        // Clicks carry the frame's time and the cursor's location, where the page got them
        #expect(telemetry.clicks.map(\.time) == frames)
        #expect(telemetry.clicks.map(\.location) == [point, CGPoint(x: 7, y: 6)])
    }

    @Test func recordsShapesWhereTheyChangeWithOneSpriteEach() {
        var take = WebTakeTelemetry(script: WebScript())
        let point = CGPoint(x: 5, y: 6)

        take.record(time: 0, cursor: point, presses: [], shape: nil)
        take.record(time: 1, cursor: point, presses: [], shape: .pointingHand)
        take.record(time: 2, cursor: point, presses: [], shape: .pointingHand)
        take.record(time: 3, cursor: point, presses: [], shape: nil)

        #expect(take.telemetry.cursorShapes.map(\.sprite) == [0, 1, 0])
        #expect(take.telemetry.cursorShapes.map(\.time) == [0, 1, 3])
        let finished = take.finished { kind, id in
            .init(id: id, kind: kind, size: CGSize(width: 1, height: 1), hotspot: .zero, png: Data())
        }
        #expect(finished.cursorSprites.map(\.kind) == [.arrow, .pointingHand])
        #expect(finished.cursorSprites.map(\.id) == [0, 1])
    }

    @Test func recordsNothingWithoutACursor() {
        var take = WebTakeTelemetry(script: WebScript())
        take.record(time: 0, cursor: nil, presses: [], shape: nil)

        #expect(take.telemetry.cursor.isEmpty)
        #expect(take.telemetry.cursorShapes.isEmpty)
    }

    @Test func mapsCSSCursorsToStandardOnes() {
        #expect(CursorKind(css: "pointer") == .pointingHand)
        #expect(CursorKind(css: "text") == .iBeam)
        #expect(CursorKind(css: "auto") == nil)
        #expect(CursorKind(css: "ew-resize") == nil)
    }

    @Test func recordsScrollingWhereTheCursorIsOrInTheMiddle() {
        var take = WebTakeTelemetry(script: WebScript())

        take.record(time: 0, cursor: nil, presses: [], shape: nil, scrolled: CGVector(dx: 0, dy: -20))
        take.record(time: 1 / 60, cursor: CGPoint(x: 5, y: 6), presses: [], shape: nil, scrolled: .zero)
        take.record(time: 2 / 60, cursor: CGPoint(x: 5, y: 6), presses: [], shape: nil, scrolled: CGVector(dx: 0, dy: 30))

        let scrolls = take.telemetry.scrolls
        #expect(scrolls.map(\.location) == [CGPoint(x: 720, y: 450), CGPoint(x: 5, y: 6)])
        #expect(scrolls.map(\.delta.dy) == [-20, 30])
    }
}
