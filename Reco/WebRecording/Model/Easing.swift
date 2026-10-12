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
        guard self != .linear else { return min(max(progress, 0), 1) }
        let (first, second) = controlPoints
        return CubicBezier(first: first, second: second)(progress)
    }
}
