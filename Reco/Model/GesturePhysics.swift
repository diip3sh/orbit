//
//  GesturePhysics.swift
//  Reco
//

import CoreGraphics
import Foundation

/// The pure maths behind drags that hand their speed to the motion that follows: where a flick
/// comes to rest, how a boundary resists, and how long a throw takes. After Apple's
/// "Designing Fluid Interfaces" (WWDC 2018).
nonisolated enum GesturePhysics {

    /// How far `velocity` (points per second) carries something that then decelerates like a
    /// scroll view: the exponential-decay form Apple ships, not `v² / 2a`.
    static func project(velocity: Double, decelerationRate: Double = 0.998) -> Double {
        velocity / 1000 * decelerationRate / (1 - decelerationRate)
    }

    /// The offset shown for a drag `overshoot` past a boundary: the further past, the less it
    /// follows, approaching `dimension`. Sign is kept.
    static func rubberband(overshoot: Double, dimension: Double, constant: Double = 0.55) -> Double {
        overshoot * dimension * constant / (dimension + constant * abs(overshoot))
    }

    /// `value` where it lies in `range`, and past either end only as far as `rubberband` lets it:
    /// what a drag shows of a pointer that has gone beyond a boundary. `dimension` as in `rubberband`.
    static func rubberbanded(_ value: Double, in range: ClosedRange<Double>, dimension: Double) -> Double {
        if value < range.lowerBound {
            return range.lowerBound + rubberband(overshoot: value - range.lowerBound, dimension: dimension)
        }
        if value > range.upperBound {
            return range.upperBound + rubberband(overshoot: value - range.upperBound, dimension: dimension)
        }
        return value
    }

    /// `velocity` as a share of the way from `start` to `target` per second, the unit a spring's
    /// initial velocity is in. Zero when there's nowhere to go.
    static func relativeVelocity(_ velocity: Double, from start: Double, to target: Double) -> Double {
        let distance = target - start
        return distance == 0 ? 0 : velocity / distance
    }

    /// How long a move over `distance` takes to leave at `velocity`, for an ease-out curve that
    /// starts at `initialSlope` (a `CAMediaTimingFunction(controlPoints: 0.25, 0.75, 0.5, 1)`
    /// starts at 3): the curve's first speed is `slope × distance / duration`.
    static func velocityMatchedDuration(
        distance: Double,
        velocity: Double,
        initialSlope: Double = 3,
        range: ClosedRange<Double> = 0.12...0.4
    ) -> Double {
        guard velocity != 0 else { return range.upperBound }
        return min(max(initialSlope * abs(distance / velocity), range.lowerBound), range.upperBound)
    }

    /// Where a flick of `frame` at `velocity` (points per second) lands, when it's thrown off
    /// `bounds`: each axis is projected separately, and it counts when the projected centre ends
    /// outside `bounds` on a side the velocity points to. Nil otherwise, so a slow drag, or a
    /// flick inwards, leaves the frame where it was dropped.
    static func flickExit(frame: CGRect, velocity: CGVector, bounds: CGRect) -> CGRect? {
        let shift = CGVector(dx: project(velocity: velocity.dx), dy: project(velocity: velocity.dy))
        let projected = frame.offsetBy(dx: shift.dx, dy: shift.dy)
        let isOutHorizontally = (projected.midX < bounds.minX && shift.dx < 0) || (projected.midX > bounds.maxX && shift.dx > 0)
        let isOutVertically = (projected.midY < bounds.minY && shift.dy < 0) || (projected.midY > bounds.maxY && shift.dy > 0)
        return isOutHorizontally || isOutVertically ? projected : nil
    }
}

/// A drag's recent speed: the points of the last 0.1 s, so a pause before release reads as rest.
/// Updated in the drag's callbacks only; holds at most the points of that window.
nonisolated struct VelocityTracker: Sendable {

    private struct Sample {
        let point: CGPoint
        let time: TimeInterval
    }

    private static let window: TimeInterval = 0.1

    private var samples: [Sample] = []

    mutating func add(_ point: CGPoint, at time: TimeInterval) {
        samples.removeAll { time - $0.time > Self.window }
        samples.append(Sample(point: point, time: time))
    }

    /// Points per second between the oldest and newest point in the window.
    var velocity: CGVector {
        guard let first = samples.first, let last = samples.last, last.time > first.time else { return .zero }
        let seconds = last.time - first.time
        return CGVector(dx: (last.point.x - first.point.x) / seconds, dy: (last.point.y - first.point.y) / seconds)
    }
}
