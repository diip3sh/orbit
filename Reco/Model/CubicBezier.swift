//
//  CubicBezier.swift
//  Reco
//

import CoreGraphics

/// A timing curve from (0, 0) to (1, 1), as CSS's `cubic-bezier(x1, y1, x2, y2)` defines it.
nonisolated struct CubicBezier: Equatable, Sendable {

    /// The control points; x within 0...1, so x grows with the curve's parameter.
    let first: CGPoint
    let second: CGPoint

    /// How far along the eased motion is when `progress` of its time has passed, both from 0 to 1.
    func callAsFunction(_ progress: Double) -> Double {
        let progress = min(max(progress, 0), 1)
        return Self.coordinate(parameter(forX: progress), first: first.y, second: second.y)
    }

    /// One coordinate of the curve at `parameter`, given that coordinate of the two control points.
    private static func coordinate(_ parameter: Double, first: Double, second: Double) -> Double {
        let inverse = 1 - parameter
        return 3 * inverse * inverse * parameter * first + 3 * inverse * parameter * parameter * second + parameter * parameter * parameter
    }

    /// The curve's parameter where its x is `target`, by bisection: x grows with the parameter, and
    /// 40 halvings land within 10⁻¹².
    private func parameter(forX target: Double) -> Double {
        var low = 0.0
        var high = 1.0
        for _ in 0..<40 {
            let middle = (low + high) / 2
            if Self.coordinate(middle, first: first.x, second: second.x) < target {
                low = middle
            } else {
                high = middle
            }
        }
        return (low + high) / 2
    }
}
