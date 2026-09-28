//
//  AutoZoomGeneratorTests.swift
//  BetterCaptureTests
//
//  Created by Diip3sh on 28.09.26.
//

import Carbon.HIToolbox
import Foundation
import Testing
@testable import BetterCapture

struct AutoZoomGeneratorTests {

    /// A 1000×500 pt display recorded at 2000×1000 px, with clicks at the given fractions of the
    /// video's width and height.
    private func telemetry(clicks: [(time: Double, point: CGPoint)], keys: [(time: Double, isRepeat: Bool)] = []) -> InputTelemetry {
        var telemetry = InputTelemetry(capture: .init(kind: .display, videoSize: CGSize(width: 2000, height: 1000)), keystrokesAvailable: true)
        telemetry.geometry = [
            .init(time: 0, screenRect: CGRect(x: 0, y: 0, width: 1000, height: 500), contentRect: CGRect(x: 0, y: 0, width: 1000, height: 500), contentScale: 1, scaleFactor: 2)
        ]
        telemetry.clicks = clicks.flatMap { click in
            let location = CGPoint(x: click.point.x * 1000, y: click.point.y * 500)
            return [
                InputTelemetry.Click(time: click.time, location: location, button: .left, isDown: true, clickCount: 1),
                InputTelemetry.Click(time: click.time + 0.1, location: location, button: .left, isDown: false, clickCount: 1)
            ]
        }
        telemetry.keys = keys.map { .init(time: $0.time, keyCode: kVK_ANSI_A, modifiers: [], isRepeat: $0.isRepeat) }
        return telemetry
    }

    private func zooms(_ telemetry: InputTelemetry, duration: Double = 20) -> [ZoomSegment] {
        AutoZoomGenerator.segments(for: telemetry, duration: duration)
    }

    @Test func zoomsOnNearbyPressesFromJustBeforeTheFirstToAWhileAfterTheLast() throws {
        let zooms = zooms(telemetry(clicks: [(1, CGPoint(x: 0.4, y: 0.4)), (2, CGPoint(x: 0.5, y: 0.5))]))

        #expect(zooms.map(\.range) == [0.5..<3.5])
        let zoom = try #require(zooms.first)
        #expect(zoom.scale == 2)
        #expect(zoom.isAutomatic)
        let center = try #require(zoom.fixedCenter)
        #expect(abs(center.x - 0.45) < 1e-9 && abs(center.y - 0.45) < 1e-9)
    }

    @Test func aLongPauseStartsAnotherZoom() {
        #expect(zooms(telemetry(clicks: [(1, CGPoint(x: 0.4, y: 0.4)), (5, CGPoint(x: 0.4, y: 0.4))])).map(\.range) == [0.5..<2.5, 4.5..<6.5])
    }

    @Test func zoomsCloseTogetherWhoseEventsFitOneViewBecomeOne() {
        #expect(zooms(telemetry(clicks: [(1, CGPoint(x: 0.4, y: 0.4)), (3.75, CGPoint(x: 0.5, y: 0.5))])).map(\.range) == [0.5..<5.25])
    }

    @Test func eventsTooFarApartForOneViewGetZoomsThatTouchSoTheViewPans() {
        let zooms = zooms(telemetry(clicks: [(1, CGPoint(x: 0.1, y: 0.1)), (2, CGPoint(x: 0.9, y: 0.9))]))

        // They'd overlap, so they meet halfway between the clicks
        #expect(zooms.map(\.range) == [0.5..<1.5, 1.5..<3.5])
        // Centred where the view stays inside the frame
        #expect(zooms.map(\.fixedCenter) == [CGPoint(x: 0.25, y: 0.25), CGPoint(x: 0.75, y: 0.75)])
    }

    @Test func keysCountAtTheLastClickButNotBeforeOneOrWhenRepeated() {
        let telemetry = telemetry(clicks: [(1, CGPoint(x: 0.4, y: 0.4))], keys: [(0.2, false), (2, false), (3.5, false), (5, false), (6, true)])

        #expect(zooms(telemetry).map(\.range) == [0.5..<6.5])
    }

    @Test func pressesOutsideTheVideoAreLeftOut() {
        // A click beside a recorded window, and the typing after it
        let telemetry = telemetry(clicks: [(1, CGPoint(x: 1.2, y: 0.4))], keys: [(2, false)])

        #expect(zooms(telemetry).isEmpty)
    }

    @Test func zoomsStayInsideTheRecordingAndLastTheMinimumWhereTheyCan() {
        #expect(zooms(telemetry(clicks: [(0.25, CGPoint(x: 0.5, y: 0.5)), (9.9, CGPoint(x: 0.5, y: 0.5))]), duration: 10).map(\.range) == [0..<1.75, 8.5..<10])
        #expect(zooms(telemetry(clicks: [(0.5, CGPoint(x: 0.5, y: 0.5))]), duration: 1).map(\.range) == [0..<1])
        #expect(zooms(telemetry(clicks: [(0.5, CGPoint(x: 0.5, y: 0.5))]), duration: 0).isEmpty)
    }

    @Test func isDeterministicWithZoomsSortedApartAndInsideTheRecording() {
        // Bursts of clicks around the screen, with pauses of varied length
        var seed: UInt64 = 42
        func random() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(1 << 53)
        }
        var time = 0.0
        let clicks = (0..<300).map { _ in
            time += random() < 0.8 ? random() : 1 + 3 * random()
            return (time: time, point: CGPoint(x: random(), y: random()))
        }
        let telemetry = telemetry(clicks: clicks)
        let duration = time + 0.5

        let zooms = zooms(telemetry, duration: duration)
        let again = self.zooms(telemetry, duration: duration)

        #expect(zooms.count > 10)
        #expect(zooms.map(\.range) == again.map(\.range))
        #expect(zooms.map(\.focus) == again.map(\.focus))
        #expect(zooms.allSatisfy { $0.range.lowerBound >= 0 && $0.range.upperBound <= duration && !$0.range.isEmpty })
        #expect(zip(zooms, zooms.dropFirst()).allSatisfy { $0.range.upperBound <= $1.range.lowerBound })
    }
}
