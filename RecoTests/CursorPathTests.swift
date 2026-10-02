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

    @Test func trailsASteadyMoveByTwoOverTheFrequency() throws {
        for smoothing in CursorStyle.Smoothing.allCases {
            var style = CursorStyle()
            style.smoothing = smoothing
            let path = try path(telemetry(cursor: sweep(speed: 600, until: 2)), style: style)

            // Settled by 1.5 s. Positions are held until the next, which trails by up to a 60 Hz sample more
            let lag = 100 + 600 * 1.5 - path.position(at: 1.5).x
            #expect(lag > 600 * 2 / smoothing.frequency && lag < 600 * (2 / smoothing.frequency + 1.0 / 60))
            // And comes to rest where the cursor did
            #expect(abs(path.position(at: 4).x - 1300) < 0.01)
        }
    }

    @Test func aWebTakesScriptedPathIsDrawnAsItWasWithoutTrailing() throws {
        var web = telemetry(cursor: sweep(speed: 600, until: 2))
        web.capture.kind = .web

        let path = try path(web)

        // Where the page's pointer was, give or take the 60 Hz sample it holds
        let behind = 100 + 600 * 1.5 - path.position(at: 1.5).x
        #expect(behind >= 0 && behind <= 600 / 60)
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

    @Test func staysWhereItIsBeforeTheEnd() throws {
        var style = CursorStyle()
        style.stopsBeforeEnd = 2
        let telemetry = telemetry(cursor: sweep(speed: 80, until: 10))

        let path = try path(telemetry, style: style)

        #expect(path.position(at: 9) == path.position(at: 8) && path.position(at: 10) == path.position(at: 8))
        #expect(path.position(at: 7) != path.position(at: 8))
        // Before the last source time shown, not the recording's end
        let trimmed = try #require(CursorPath(telemetry: telemetry, style: style, duration: 10, videoHeight: 800, shown: 1..<6))
        #expect(trimmed.position(at: 6) == trimmed.position(at: 4) && trimmed.position(at: 3.9) != trimmed.position(at: 4))
    }

    @Test func glidesBackToItsFirstPositionOverTheLastSecond() throws {
        var style = CursorStyle()
        style.loopsToStart = true
        let telemetry = telemetry(cursor: sweep(speed: 80, until: 10))
        let plain = try path(telemetry)

        let path = try path(telemetry, style: style)

        #expect(path.position(at: 9) == plain.position(at: 9))
        #expect(abs(path.position(at: 10).x - path.position(at: 0).x) < 1e-9)
        let halfway = path.position(at: 9.5)
        #expect(abs(halfway.x - (plain.position(at: 9.5).x + plain.position(at: 0).x) / 2) < 1e-9)

        let trimmed = try #require(CursorPath(telemetry: telemetry, style: style, duration: 10, videoHeight: 800, shown: 2..<6))
        #expect(abs(trimmed.position(at: 6).x - plain.position(at: 2).x) < 1e-9 && trimmed.position(at: 5) == plain.position(at: 5))
    }

    @Test func leansTheWayItMovesAndNotAtRest() throws {
        var style = CursorStyle()
        style.tilts = true
        // 1500 pt/s to the right until 0.5 s, then still; 2 px per point
        let telemetry = telemetry(cursor: sweep(speed: 1500, until: 0.5), scaleFactor: 2)

        let path = try path(telemetry, style: style)

        // The smoothed cursor has reached the move's speed: clockwise by tanh(1) of the most
        #expect(abs(path.tilt(at: 0.45) + CursorPath.maximumTilt * tanh(1)) < 0.005)
        #expect(abs(path.tilt(at: 3)) < 1e-6)
        #expect(try self.path(telemetry).tilt(at: 0.45) == 0)
    }
}
