//
//  GesturePhysicsTests.swift
//  RecoTests
//

import CoreGraphics
import Testing
@testable import Reco

struct GesturePhysicsTests {

    @Test func projectsAThousandPointsPerSecondToJustUnderFiveHundredPoints() {
        #expect(abs(GesturePhysics.project(velocity: 1000) - 499) < 0.001)
        #expect(abs(GesturePhysics.project(velocity: -1000) + 499) < 0.001)
        #expect(GesturePhysics.project(velocity: 0) == 0)
    }

    @Test func rubberbandKeepsTheSignAndFollowsLessThanTheDrag() {
        #expect(GesturePhysics.rubberband(overshoot: 0, dimension: 400) == 0)
        let shown = GesturePhysics.rubberband(overshoot: 100, dimension: 400)
        #expect(shown > 0 && shown < 100)
        #expect(GesturePhysics.rubberband(overshoot: -100, dimension: 400) == -shown)
    }

    @Test func rubberbandApproachesTheDimension() {
        let shown = GesturePhysics.rubberband(overshoot: 1_000_000, dimension: 400)
        #expect(shown < 400)
        #expect(shown > 399)
    }

    @Test func aDragInsideItsRangeIsShownAsIs() {
        #expect(GesturePhysics.rubberbanded(40, in: 0...100, dimension: 400) == 40)
        #expect(GesturePhysics.rubberbanded(100, in: 0...100, dimension: 400) == 100)
    }

    @Test func aDragPastEitherEndResistsFromThatEnd() {
        let past = GesturePhysics.rubberbanded(160, in: 0...100, dimension: 400)
        #expect(past > 100 && past < 160)
        let before = GesturePhysics.rubberbanded(-60, in: 0...100, dimension: 400)
        #expect(before < 0 && before > -60)
        #expect(GesturePhysics.rubberbanded(200, in: 0...100, dimension: 400) > past)
    }

    @Test func relativeVelocityIsTheShareOfTheWayPerSecond() {
        #expect(GesturePhysics.relativeVelocity(50, from: 50, to: 150) == 0.5)
        #expect(GesturePhysics.relativeVelocity(50, from: 80, to: 80) == 0)
    }

    @Test func aThrowTakesAsLongAsItsFirstSpeedNeedsAndNoLessThanTheRange() {
        #expect(abs(GesturePhysics.velocityMatchedDuration(distance: 300, velocity: 3000) - 0.3) < 0.0001)
        #expect(GesturePhysics.velocityMatchedDuration(distance: 100, velocity: 10_000) == 0.12)
        #expect(GesturePhysics.velocityMatchedDuration(distance: 800, velocity: 1000) == 0.4)
        #expect(GesturePhysics.velocityMatchedDuration(distance: 100, velocity: 0) == 0.4)
    }

    private let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let card = CGRect(x: 16, y: 300, width: 230, height: 210)

    @Test func aSlowDragLeavesTheCardWhereItIs() {
        #expect(GesturePhysics.flickExit(frame: card, velocity: CGVector(dx: -50, dy: 0), bounds: bounds) == nil)
        #expect(GesturePhysics.flickExit(frame: card, velocity: .zero, bounds: bounds) == nil)
    }

    @Test func aFastFlickTowardTheNearEdgeThrowsTheCardOff() {
        let landed = GesturePhysics.flickExit(frame: card, velocity: CGVector(dx: -2000, dy: 0), bounds: bounds)
        #expect(landed != nil)
        #expect(landed?.midX ?? 0 < bounds.minX)
        #expect(landed?.origin.y == card.origin.y)
    }

    @Test func aFlickInwardsKeepsTheCard() {
        // Lands at 630, short of the far edge; a throw clean across the screen would count as off
        #expect(GesturePhysics.flickExit(frame: card, velocity: CGVector(dx: 1000, dy: 0), bounds: bounds) == nil)
    }

    @Test func oneSampleHasNoVelocity() {
        var tracker = VelocityTracker()
        tracker.add(CGPoint(x: 5, y: 5), at: 1)
        #expect(tracker.velocity == .zero)
    }

    @Test func twoSamplesGiveTheirSpeed() {
        var tracker = VelocityTracker()
        tracker.add(CGPoint(x: 0, y: 0), at: 1)
        tracker.add(CGPoint(x: 10, y: 0), at: 1.05)
        #expect(abs(tracker.velocity.dx - 200) < 0.001)
        #expect(tracker.velocity.dy == 0)
    }

    @Test func samplesOlderThanTheWindowAreDropped() {
        var tracker = VelocityTracker()
        tracker.add(CGPoint(x: 0, y: 0), at: 1)
        tracker.add(CGPoint(x: 100, y: 0), at: 2)
        tracker.add(CGPoint(x: 110, y: 0), at: 2.05)
        #expect(abs(tracker.velocity.dx - 200) < 0.001)
    }
}
