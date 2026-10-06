//
//  MotionEasing.swift
//  Reco
//

import CoreGraphics

/// How a value moves from one keyframe to the next. No bounce, back or elastic exists to choose:
/// the reference videos never overshoot (spec 0011, *Craft defaults*).
///
/// Coded the way a person or an agent writes it: `"linear"`, `"hold"`, `[x1, y1, x2, y2]` for a
/// cubic Bézier as in CSS, or `{"spring": response}`.
nonisolated enum MotionEasing: Equatable, Sendable {
    case linear

    /// Keeps the first value until the next keyframe.
    case hold

    /// A CSS `cubic-bezier()`: control points (x1, y1) and (x2, y2), x within 0...1.
    case cubicBezier(Double, Double, Double, Double)

    /// A critically damped spring that settles in about `response` seconds, scaled to land exactly
    /// on the next keyframe.
    case spring(response: Double)

    /// The share of the way from one keyframe's value to the next's, `fraction` of the way through
    /// a segment `duration` seconds long.
    func progress(_ fraction: Double, duration: Double) -> Double {
        let fraction = min(max(fraction, 0), 1)
        switch self {
        case .linear:
            return fraction
        case .hold:
            return fraction < 1 ? 0 : 1
        case let .cubicBezier(firstX, firstY, secondX, secondY):
            return CubicBezier(first: CGPoint(x: firstX, y: firstY), second: CGPoint(x: secondX, y: secondY))(fraction)
        case .spring(let response):
            // 1 - (1 + ωt)e^(-ωt) with ω = 2π / response, divided by its value at the segment's end
            let omega = 2 * Double.pi / max(response, 1e-3)
            let settled = { (time: Double) in 1 - (1 + omega * time) * exp(-omega * time) }
            let end = settled(duration)
            return end > 0 ? settled(fraction * duration) / end : fraction
        }
    }
}

// MARK: - Codable

nonisolated extension MotionEasing: Codable {

    nonisolated private struct SpringKey: Codable {
        var spring: Double
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let name = try? container.decode(String.self) {
            switch name {
            case "linear": self = .linear
            case "hold": self = .hold
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown easing \"\(name)\"")
            }
        } else if let points = try? container.decode([Double].self) {
            guard points.count == 4, (0...1).contains(points[0]), (0...1).contains(points[2]) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "A cubic Bézier is [x1, y1, x2, y2] with x in 0...1")
            }
            self = .cubicBezier(points[0], points[1], points[2], points[3])
        } else {
            let spring = try container.decode(SpringKey.self).spring
            guard spring > 0 else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "A spring's response must be positive")
            }
            self = .spring(response: spring)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .linear: try container.encode("linear")
        case .hold: try container.encode("hold")
        case let .cubicBezier(firstX, firstY, secondX, secondY): try container.encode([firstX, firstY, secondX, secondY])
        case .spring(let response): try container.encode(SpringKey(spring: response))
        }
    }
}
