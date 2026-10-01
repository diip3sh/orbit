//
//  Easing.swift
//  Reco
//

import CoreGraphics

/// How a scroll or a cursor move speeds up and slows down: CSS's timing functions.
nonisolated enum Easing: String, Codable, CaseIterable, Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut

    /// The cubic Bézier's two control points, as CSS defines them (`cubic-bezier(x1, y1, x2, y2)`).
    var controlPoints: (first: CGPoint, second: CGPoint) {
        switch self {
        case .linear: (CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1))
        case .easeIn: (CGPoint(x: 0.42, y: 0), CGPoint(x: 1, y: 1))
        case .easeOut: (CGPoint(x: 0, y: 0), CGPoint(x: 0.58, y: 1))
        case .easeInOut: (CGPoint(x: 0.42, y: 0), CGPoint(x: 0.58, y: 1))
        }
    }

    /// How far along the eased motion is when `progress` of its time has passed, both from 0 to 1.
    func callAsFunction(_ progress: Double) -> Double {
        let progress = min(max(progress, 0), 1)
        guard self != .linear else { return progress }
        let (first, second) = controlPoints
        let parameter = Self.parameter(forX: progress, first: first.x, second: second.x)
        return Self.bezier(parameter, first: first.y, second: second.y)
    }

    /// One coordinate of the curve from (0, 0) to (1, 1) at `parameter`, given that coordinate of
    /// the two control points.
    private static func bezier(_ parameter: Double, first: Double, second: Double) -> Double {
        let inverse = 1 - parameter
        return 3 * inverse * inverse * parameter * first + 3 * inverse * parameter * parameter * second + parameter * parameter * parameter
    }

    /// The curve's parameter where its x is `target`, by bisection: x grows with the parameter for CSS's
    /// curves, and 40 halvings land within 10⁻¹².
    private static func parameter(forX target: Double, first: Double, second: Double) -> Double {
        var low = 0.0
        var high = 1.0
        for _ in 0..<40 {
            let middle = (low + high) / 2
            if bezier(middle, first: first, second: second) < target {
                low = middle
            } else {
                high = middle
            }
        }
        return (low + high) / 2
    }
}
