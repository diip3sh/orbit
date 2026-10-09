//
//  CursorPathTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct CursorPathTests {

    /// A 1000×800 pt display recorded at 1 px per point: screen points are video pixels, and Core
    /// Image's y is 800 minus the screen's.
    private func telemetry(
        cursor: [(time: Double, point: CGPoint)], clicks: [InputTelemetry.Click] = [], scaleFactor: CGFloat = 1
    ) -> InputTelemetry {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        var telemetry = InputTelemetry(capture: .init(kind: .display, videoSize: screen.size, cursorInVideo: false), keystrokesAvailable: false)
        telemetry.geometry = [.init(time: 0, screenRect: screen, contentRect: screen, contentScale: 1, scaleFactor: scaleFactor)]
        telemetry.cursor = cursor.map { InputTelemetry.CursorSample(time: $0.time, location: $0.point) }
        telemetry.clicks = clicks
        return telemetry
    }

    private func path(_ telemetry: InputTelemetry, style: CursorStyle = CursorStyle(), duration: Double = 10) throws -> CursorPath {
        try #require(CursorPath(telemetry: telemetry, style: style, duration: duration, videoHeight: 800))
    }

    private func click(at time: Double, _ point: CGPoint, isDown: Bool = true) -> InputTelemetry.Click {
        .init(time: time, location: point, button: .left, isDown: isDown, clickCount: 1)
    }

    /// Moves right across the screen at `speed` points per second, sampled at 60 Hz, from x = 100.
    private func sweep(speed: Double, until end: Double) -> [(time: Double, point: CGPoint)] {
        (0...Int(end * 60)).map { (Double($0) / 60, CGPoint(x: 100 + speed * Double($0) / 60, y: 400)) }
    }

    @Test func needsPositionsAndGeometry() {
        var telemetry = telemetry(cursor: [])
        #expect(CursorPath(telemetry: telemetry, style: CursorStyle(), duration: 10, videoHeight: 800) == nil)

        telemetry.cursor = [.init(time: 0, location: .zero)]
        telemetry.geometry = []
        #expect(CursorPath(telemetry: telemetry, style: CursorStyle(), duration: 10, videoHeight: 800) == nil)
    }

    @Test func passesThroughEveryClickAtItsTimeWithoutJumps() throws {
        // A click mid-sweep, where the smoothed cursor trails, and one after it stops
        let path = try path(telemetry(
            cursor: sweep(speed: 800, until: 1),
            clicks: [click(at: 0.5, CGPoint(x: 500, y: 400)), click(at: 0.55, CGPoint(x: 540, y: 400), isDown: false), click(at: 1.5, CGPoint(x: 900, y: 400))]
        ))

        for (time, left) in [(0.5, 500.0), (0.55, 540), (1.5, 900)] {
            let position = path.position(at: time)
            #expect(abs(position.x - left) < 1e-9 && abs(position.y - 400) < 1e-9)
        }
        // The raw cursor moves 0.8 px a millisecond
        let positions = (0...2000).map { path.position(at: Double($0) / 1000) }
        for (before, after) in zip(positions, positions.dropFirst()) {
            #expect(hypot(after.x - before.x, after.y - before.y) < 2)
        }
    }

    @Test func withoutSmoothingTheCursorIsWhereItWasRecordedJitterIncluded() throws {
        // A zig-zag with a 1 pt move back, which smoothing would drop as jitter
        let moves: [(time: Double, point: CGPoint)] = [(0, CGPoint(x: 100, y: 100)), (0.1, CGPoint(x: 300, y: 150)), (0.2, CGPoint(x: 299, y: 150)), (0.3, CGPoint(x: 500, y: 400))]
        var style = CursorStyle()
        style.smoothing = .off
        let path = try path(telemetry(cursor: moves), style: style)

        // Core Image's y is 800 minus the screen's; a position is held until the next, like the recording's
        for (time, point) in moves {
            let position = path.position(at: time + 0.001)
            #expect(abs(position.x - point.x) < 1e-9 && abs(position.y - (800 - point.y)) < 1e-9)
        }
        #expect(abs(path.position(at: 0.15).x - 300) < 1e-9)
    }

    @Test func trailsASteadyMoveByTwoOverTheFrequency() throws {
        for smoothing in CursorStyle.Smoothing.allCases where smoothing.frequency != nil {
            var style = CursorStyle()
            style.smoothing = smoothing
            let path = try path(telemetry(cursor: sweep(speed: 600, until: 2)), style: style)

            // Settled by 1.5 s. Positions are held until the next, which trails by up to a 60 Hz sample more
            let frequency = try #require(smoothing.frequency)
            let lag: Double = 100 + 600 * 1.5 - path.position(at: 1.5).x
            let settled: Double = 600 * 2 / frequency
            let sample: Double = 600 / 60
            #expect(lag > settled)
            #expect(lag < settled + sample)
            // And comes to rest where the cursor did
            #expect(abs(path.position(at: 4).x - 1300) < 0.01)
        }
    }

    @Test func dropsTinyMovesBackButNotRealOnes() {
        let samples = [(0, 0), (1, 10), (2, 9), (3, 12), (4, 5)].map {
            InputTelemetry.CursorSample(time: Double($0.0), location: CGPoint(x: $0.1, y: 0))
        }

        // 1 pt back is jitter; 7 pt back isn't
        #expect(CursorPath.withoutJitter(samples).map(\.time) == [0, 1, 3, 4])
    }

    @Test func placesPositionsWithTheGeometryInEffect() throws {
        var telemetry = telemetry(cursor: [(0, CGPoint(x: 500, y: 300))])
        var moved = telemetry.geometry[0]
        moved.time = 1
        moved.screenRect.origin.x = 100
        telemetry.geometry.append(moved)

        let path = try path(telemetry)

        #expect(path.position(at: 0.9) == CGPoint(x: 500, y: 500))
        // The captured display moved 100 pt right, so the cursor is 100 px further left in it
        #expect(abs(path.position(at: 3).x - 400) < 1e-3)
    }

    @Test func shrinksWhileAButtonIsHeld() throws {
        let clicks = [click(at: 1, CGPoint(x: 100, y: 100)), click(at: 2, CGPoint(x: 100, y: 100), isDown: false)]
        var style = CursorStyle()
        style.size = 1.5
        let path = try path(telemetry(cursor: [(0, CGPoint(x: 100, y: 100))], clicks: clicks, scaleFactor: 2), style: style)

        // 2 px per point, 1.5 times the size
        #expect(path.scale(at: 0.5) == 3)
        #expect(abs(path.scale(at: 1.065) - 2.7) < 1e-9)
        #expect(abs(path.scale(at: 1.5) - 2.4) < 1e-9)
        #expect(abs(path.scale(at: 2.065) - 2.7) < 1e-9)
        #expect(path.scale(at: 2.2) == 3)

        style.animatesClicks = false
        let still = try self.path(telemetry(cursor: [(0, CGPoint(x: 100, y: 100))], clicks: clicks, scaleFactor: 2), style: style)
        #expect(still.scale(at: 1.5) == 3)
    }

    @Test func fadesOutWhenIdleAndBackInBeforeItMovesOrClicks() throws {
        let telemetry = telemetry(
            cursor: [(0, CGPoint(x: 100, y: 100)), (1, CGPoint(x: 200, y: 100)), (6, CGPoint(x: 300, y: 100))],
            clicks: [click(at: 5, CGPoint(x: 200, y: 100))]
        )
        var style = CursorStyle()
        style.hidesWhenIdle = true

        let path = try path(telemetry, style: style)

        // Idle from 3 s, 2 s after the move at 1 s, until the click at 5 s; then from 8 s to the end
        let opacities = [2.9, 3.15, 4, 4.85, 5, 7, 8.15, 9].map { path.opacity(at: $0) }
        let expected = [1, 0.5, 0, 0.5, 1, 1, 0.5, 0]
        #expect(zip(opacities, expected).allSatisfy { abs($0 - $1) < 1e-9 })

        #expect(try self.path(telemetry).opacity(at: 4) == 1)
    }

    @Test func glidesOntoTheFirstFramesPositionOverTheLoop() throws {
        let cursor = sweep(speed: 100, until: 9.5)
        let telemetry = telemetry(cursor: cursor, clicks: [click(at: 8.5, CGPoint(x: 900, y: 400))])
        let plain = try path(telemetry)

        let looping = try #require(CursorPath(
            telemetry: telemetry, style: CursorStyle(), duration: 10, videoHeight: 800, loop: .init(start: 0.5, glide: 8..<9.5)
        ))

        // Before the glide it is the plain path
        #expect(looping.position(at: 3) == plain.position(at: 3))
        #expect(looping.position(at: 8) == plain.position(at: 8))
        // At its end, and after, where the first frame is, which the glide doesn't change
        for time in [9.5, 9.9] {
            #expect(looping.position(at: time) == plain.position(at: 0.5))
        }
        // Half way there it is between, on the way
        let middle = looping.position(at: 8.75)
        #expect(middle.x > plain.position(at: 0.5).x && middle.x < plain.position(at: 8.75).x)
    }

    @Test func aGlideOfNoLengthMovesTheCursorAtOnce() throws {
        let telemetry = telemetry(cursor: sweep(speed: 100, until: 5))

        let looping = try #require(CursorPath(
            telemetry: telemetry, style: CursorStyle(), duration: 10, videoHeight: 800, loop: .init(start: 0, glide: 4..<4)
        ))

        #expect(looping.position(at: 3.9).x > 400)
        #expect(looping.position(at: 4) == looping.position(at: 0))
    }

    @Test func holdsStillFromTheStop() throws {
        // Still moving, and with a button held, when it stops at 7 s
        let telemetry = telemetry(
            cursor: sweep(speed: 100, until: 9.5),
            clicks: [click(at: 6.9, CGPoint(x: 790, y: 400)), click(at: 7.5, CGPoint(x: 850, y: 400), isDown: false)]
        )
        let plain = try path(telemetry)
        let stopping = try #require(CursorPath(telemetry: telemetry, style: CursorStyle(), duration: 10, videoHeight: 800, stop: 7))

        #expect(stopping.position(at: 5) == plain.position(at: 5))
        for time in [7.5, 8, 9.9] {
            #expect(stopping.position(at: time) == plain.position(at: 7))
            #expect(stopping.scale(at: time) == plain.scale(at: 7))
        }
        #expect(plain.position(at: 8).x > plain.position(at: 7).x + 50)
        #expect(plain.scale(at: 7) < 1)
    }

    @Test func leansAgainstTheMoveAndStraightensAtRest() throws {
        var style = CursorStyle()
        let still = try path(telemetry(cursor: sweep(speed: 800, until: 1)), style: style)
        #expect(still.tilt(at: 0.5) == 0)

        style.tilts = true
        let right = try path(telemetry(cursor: sweep(speed: 800, until: 1)), style: style)
        // Clockwise moving right, by most of the maximum at the tilt speed, and upright once settled
        #expect(right.tilt(at: 0.8) < -CursorPath.maximumTilt * 0.6 && right.tilt(at: 0.8) > -CursorPath.maximumTilt)
        #expect(abs(right.tilt(at: 4)) < 1e-3)

        let left = try path(telemetry(cursor: sweep(speed: -400, until: 0.2)), style: style)
        #expect(left.tilt(at: 0.2) > 0)
    }
}
