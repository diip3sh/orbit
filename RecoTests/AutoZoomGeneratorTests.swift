//
//  AutoZoomGeneratorTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import Carbon.HIToolbox
import Foundation
import Testing
@testable import Reco

struct AutoZoomGeneratorTests {

    /// A 1000×500 pt display recorded at 2000×1000 px, with clicks and cursor samples at the given
    /// fractions of the video's width and height.
    private func telemetry(
        clicks: [(time: Double, point: CGPoint)] = [],
        keys: [(time: Double, isRepeat: Bool)] = [],
        cursor: [(time: Double, point: CGPoint)] = []
    ) -> InputTelemetry {
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
        telemetry.cursor = cursor.map { .init(time: $0.time, location: CGPoint(x: $0.point.x * 1000, y: $0.point.y * 500)) }
        return telemetry
    }

    private func zooms(_ telemetry: InputTelemetry, duration: Double = 20) -> [ZoomSegment] {
        AutoZoomGenerator.segments(for: telemetry, duration: duration)
    }

    /// The cursor going round `center` from `start`, sampled every 1/8 s, 12.5 samples a turn.
    private func circling(around center: CGPoint, radius: Double, from start: Double = 3, samples: Int) -> [(time: Double, point: CGPoint)] {
        (0..<samples).map { step in
            let angle = 2 * Double.pi * Double(step) / 12.5
            return (start + Double(step) / 8, CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
        }
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

    @Test func zoomsWhereTheCursorRestsAfterMovingThere() throws {
        // From the corner to the middle in 0.75 s, then still
        // Typed out: Xcode 26.6, which the release workflow builds with, can't infer this closure
        let move = (0...3).map { (step: Int) -> (time: Double, point: CGPoint) in
            let offset = Double(step)
            return (time: 1 + 0.25 * offset, point: CGPoint(x: 0.1 + 0.15 * offset, y: 0.1 + 0.1 * offset))
        }
        let zooms = zooms(telemetry(cursor: [(0, CGPoint(x: 0.1, y: 0.1))] + move))

        #expect(zooms.map(\.range) == [1.25..<3.25])
        let center = try #require(zooms.first?.fixedCenter)
        #expect(abs(center.x - 0.55) < 1e-9 && abs(center.y - 0.4) < 1e-9)
    }

    @Test func aCursorPassingThroughNudgedOrOutsideTheVideoDoesNotZoom() {
        // Moving steadily, a rest a nudge away from the last one, and a rest beside the video
        let moving = (0..<20).map { (time: 0.1 * Double($0), point: CGPoint(x: 0.05 * Double($0), y: 0.5)) }
        let nudged = [(time: 0.0, point: CGPoint(x: 0.5, y: 0.5)), (1, CGPoint(x: 0.6, y: 0.55))]
        let outside = [(time: 0.0, point: CGPoint(x: 0.5, y: 0.5)), (1, CGPoint(x: 1.3, y: 0.5))]

        #expect(zooms(telemetry(cursor: moving), duration: 1.95).isEmpty)
        #expect(zooms(telemetry(cursor: nudged)).isEmpty)
        #expect(zooms(telemetry(cursor: outside)).isEmpty)
    }

    @Test func zoomsOnWhatTheCursorCirclesFromWhenItStartsToAWhileAfter() throws {
        // Almost three turns, two of them whole
        let telemetry = telemetry(cursor: circling(around: CGPoint(x: 0.6, y: 0.4), radius: 0.05, samples: 38))

        #expect(AutoZoomGenerator.circles(in: telemetry).map(\.range) == [3...4.75, 4.75...6.5])
        let zooms = zooms(telemetry)
        #expect(zooms.map(\.range) == [2.5..<8])
        let center = try #require(zooms.first?.fixedCenter)
        #expect(abs(center.x - 0.6) < 0.01 && abs(center.y - 0.4) < 0.01)
    }

    @Test func circlingTooSmallTooWideNotAllTheWayRoundOrOutsideTheVideoAndShakingDoNotZoom() {
        let center = CGPoint(x: 0.5, y: 0.5)
        let shaking = (0...40).map { (time: 3 + 0.05 * Double($0), point: $0.isMultiple(of: 2) ? CGPoint(x: 0.4, y: 0.5) : CGPoint(x: 0.6, y: 0.51)) }

        #expect(zooms(telemetry(cursor: circling(around: center, radius: 0.003, samples: 38))).isEmpty)
        #expect(zooms(telemetry(cursor: circling(around: center, radius: 0.25, samples: 26))).isEmpty)
        #expect(zooms(telemetry(cursor: circling(around: center, radius: 0.05, samples: 12))).isEmpty)
        #expect(zooms(telemetry(cursor: circling(around: CGPoint(x: 1.2, y: 0.5), radius: 0.05, samples: 38))).isEmpty)
        #expect(zooms(telemetry(cursor: shaking)).isEmpty)
    }

    @Test func theMoveIntoACircleIsLeftOutOfIt() throws {
        // Straight from the left to where the circling starts, turning into it
        let approach = (0..<7).map { (time: 2.125 + Double($0) / 8, point: CGPoint(x: 0.3 + 0.05 * Double($0), y: 0.4)) }
        let telemetry = telemetry(cursor: approach + circling(around: CGPoint(x: 0.6, y: 0.4), radius: 0.05, samples: 38))

        let circle = try #require(AutoZoomGenerator.circles(in: telemetry).first)
        // At most from where the move reaches the circle's left edge
        #expect(circle.range.lowerBound >= 2.75)
        #expect(abs(circle.bounds.midX - 0.6) < 0.01 && abs(circle.bounds.midY - 0.4) < 0.01)
    }

    @Test func aRestBeforeAClickThereJoinsItsZoom() {
        let telemetry = telemetry(clicks: [(2, CGPoint(x: 0.6, y: 0.5))], cursor: [(0, CGPoint(x: 0.1, y: 0.1)), (1, CGPoint(x: 0.6, y: 0.5))])

        #expect(zooms(telemetry).map(\.range) == [0.5..<3.5])
    }

    @Test func aWebTakeZoomsOnEachStopForAsLongAsItLastsUntilThePageScrolls() throws {
        // Stops at 1 s and at 3.5 s, 5% of the video away, which a screen recording wouldn't count;
        // then the page scrolls from 7 s under the resting cursor
        var web = telemetry(cursor: [(0, CGPoint(x: 0.5, y: 0.5)), (1, CGPoint(x: 0.2, y: 0.3)), (3.5, CGPoint(x: 0.25, y: 0.3))])
        web.capture.kind = .web
        web.scrolls = (420...540).map { .init(time: Double($0) / 60, location: CGPoint(x: 250, y: 150), delta: CGVector(dx: 0, dy: -5)) }

        let zooms = zooms(web)

        // From the first stop's lead to just after the scroll starts, both stops in one view
        let zoom = try #require(zooms.first)
        #expect(zooms.count == 1)
        #expect(zoom.range == 0.5..<7.3)
        // A screen recording's zoom from the first arrival only
        #expect(AutoZoomGenerator.segments(for: web, duration: 20, configuration: AutoZoomGenerator.Configuration()).map(\.range) == [0.5..<2.5])
    }

    @Test func aWebTakesZoomOnAClickEndsWhenThePageItOpensAppears() throws {
        // The cursor arrives on a link at 2 s and clicks it at 3 s; the new page shows at 3.1 s
        var web = telemetry(clicks: [(3, CGPoint(x: 0.3, y: 0.1))], cursor: [(0, CGPoint(x: 0.5, y: 0.5)), (2, CGPoint(x: 0.3, y: 0.1))])
        web.capture.kind = .web
        var opened = web
        opened.navigations = [.init(time: 3.1, url: "https://example.com/plan")]

        let stays = zooms(web)
        let moves = zooms(opened)

        // On one page the zoom holds while the cursor rests there; the new page shows whole shortly after it appears
        #expect(stays.map(\.range) == [1.5..<20])
        #expect(moves.map(\.range) == [1.5..<3.4])
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
