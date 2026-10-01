//
//  CameraPathTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import Foundation
import Testing
@testable import Reco

struct CameraPathTests {

    private func zoom(_ range: Range<Double>, at center: CGPoint, scale: Double = 2) -> ZoomSegment {
        ZoomSegment(range: range, scale: scale, focus: .fixed(center: center))
    }

    private func isClose(_ viewport: CameraPath.Viewport, to expected: CameraPath.Viewport) -> Bool {
        abs(viewport.center.x - expected.center.x) < 1e-9 && abs(viewport.center.y - expected.center.y) < 1e-9
            && abs(viewport.scale - expected.scale) < 1e-9
    }

    @Test func showsTheWholeFrameWithoutZooms() {
        let path = CameraPath(zooms: [], cursor: [], duration: 10)

        #expect(path.viewport(at: 0) == .whole)
        #expect(path.viewport(at: 5) == .whole)
    }

    @Test func startsZoomingAtTheStartAndSettlesOnTheTarget() {
        let path = CameraPath(zooms: [zoom(1..<5, at: CGPoint(x: 0.3, y: 0.6))], cursor: [], duration: 10)

        #expect(path.viewport(at: 1) == .whole)
        #expect(path.viewport(at: 1.5).scale > 1.8)
        #expect(isClose(path.viewport(at: 4), to: CameraPath.Viewport(center: CGPoint(x: 0.3, y: 0.6), scale: 2)))
    }

    @Test func reachesTheWholeFrameBetweenZooms() {
        let path = CameraPath(zooms: [zoom(1..<3, at: CGPoint(x: 0.3, y: 0.6)), zoom(6..<8, at: CGPoint(x: 0.7, y: 0.4))], cursor: [], duration: 10)

        #expect(path.viewport(at: 3.5).scale > 1)
        #expect(path.viewport(at: 5) == .whole)
        #expect(path.viewport(at: 9.9) == .whole)
    }

    /// Zooms 3× into one corner, pans straight to the opposite one, then zooms out.
    private let cornerToCorner = CameraPath(
        zooms: [
            ZoomSegment(range: 0.5..<3, scale: 3, focus: .fixed(center: CGPoint(x: 1, y: 0))),
            ZoomSegment(range: 3..<6, scale: 3, focus: .fixed(center: CGPoint(x: 0, y: 1)))
        ],
        cursor: [],
        duration: 8
    )

    @Test func movesWithoutJumps() {
        let viewports = (0...960).map { cornerToCorner.viewport(at: Double($0) / 120) }

        // At its fastest, the pan moves the view 0.02 of the frame per sample, and zooming out of 3× 0.08×
        for (before, after) in zip(viewports, viewports.dropFirst()) {
            #expect(abs(after.center.x - before.center.x) < 0.025)
            #expect(abs(after.center.y - before.center.y) < 0.025)
            #expect(abs(after.scale - before.scale) < 0.1)
        }
    }

    @Test func keepsTheViewInsideTheFrame() {
        // Between samples too
        for viewport in (0...1920).map({ cornerToCorner.viewport(at: Double($0) / 240) }) {
            let margin = 0.5 / viewport.scale
            #expect(viewport.scale >= 1)
            #expect(viewport.center.x - margin >= -1e-9 && viewport.center.x + margin <= 1 + 1e-9)
            #expect(viewport.center.y - margin >= -1e-9 && viewport.center.y + margin <= 1 + 1e-9)
        }
        #expect(isClose(cornerToCorner.viewport(at: 2.9), to: CameraPath.Viewport(center: CGPoint(x: 5.0 / 6, y: 1.0 / 6), scale: 3)))
    }

    @Test func followingMovesTheViewOnlyWhenTheCursorLeavesItsMiddle() {
        // At 2×, the dead zone reaches 0.125 of the frame either side of the centre
        let center = CGPoint(x: 0.5, y: 0.5)

        #expect(CameraPath.following(CGPoint(x: 0.55, y: 0.4), from: center, scale: 2) == center)
        #expect(CameraPath.following(CGPoint(x: 0.75, y: 0.5), from: center, scale: 2) == CGPoint(x: 0.625, y: 0.5))
        #expect(CameraPath.following(CGPoint(x: 0.1, y: 0.5), from: nil, scale: 2) == CGPoint(x: 0.25, y: 0.5))
    }

    @Test func aZoomFollowingTheCursorKeepsItInView() {
        let cursor = [(time: 0.0, point: CGPoint(x: 0.5, y: 0.5)), (time: 3.0, point: CGPoint(x: 0.9, y: 0.55))]
        let path = CameraPath(zooms: [ZoomSegment(range: 0..<10, focus: .followCursor)], cursor: cursor, duration: 10)

        #expect(isClose(path.viewport(at: 2.9), to: CameraPath.Viewport(center: CGPoint(x: 0.5, y: 0.5), scale: 2)))
        // Moved right as far as the frame allows; the small move down stays inside the dead zone
        #expect(isClose(path.viewport(at: 6), to: CameraPath.Viewport(center: CGPoint(x: 0.75, y: 0.5), scale: 2)))
    }

    @Test func aZoomFollowingNoCursorCentresOnTheFrame() {
        let path = CameraPath(zooms: [ZoomSegment(range: 0..<10, focus: .followCursor)], cursor: [], duration: 10)

        #expect(isClose(path.viewport(at: 5), to: CameraPath.Viewport(center: CGPoint(x: 0.5, y: 0.5), scale: 2)))
    }
}
