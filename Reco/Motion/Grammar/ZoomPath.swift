//
//  ZoomPath.swift
//  Reco
//

import CoreGraphics
import Foundation

/// The smooth, efficient way between two views (van Wijk and Nuij 2003, as d3-interpolate's
/// `interpolateZoom`): a long pan zooms out on the way, so it never looks like a blur of content.
nonisolated struct ZoomPath: Sendable {

    /// How much the path zooms out for distance: √2, d3's and the paper's choice.
    static let rho = 2.0.squareRoot()

    private let start: CGPoint
    private let delta: CGVector
    private let startWidth: Double
    private let endWidth: Double
    private let distance: Double
    private let startAngle: Double

    /// The path's length in the paper's units: about 1.25 for a pan by one view's width.
    let length: Double

    /// From a view of `startWidth` canvas pixels centred on `start` to one of `endWidth` on `end`.
    init(from start: CGPoint, width startWidth: Double, to end: CGPoint, width endWidth: Double) {
        let rho = Self.rho
        self.start = start
        delta = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        self.startWidth = startWidth
        self.endWidth = endWidth
        let squared = delta.dx * delta.dx + delta.dy * delta.dy
        distance = squared.squareRoot()
        if squared < 1e-12 {
            startAngle = 0
            length = abs(log(endWidth / startWidth)) / rho
        } else {
            let first = (endWidth * endWidth - startWidth * startWidth + pow(rho, 4) * squared) / (2 * startWidth * rho * rho * distance)
            let second = (endWidth * endWidth - startWidth * startWidth - pow(rho, 4) * squared) / (2 * endWidth * rho * rho * distance)
            startAngle = log((first * first + 1).squareRoot() - first)
            length = (log((second * second + 1).squareRoot() - second) - startAngle) / rho
        }
    }

    /// The view `fraction` of the way along.
    func view(at fraction: Double) -> (center: CGPoint, width: Double) {
        let rho = Self.rho
        let travelled = fraction * length
        guard distance > 1e-6 else {
            let width = startWidth * exp((endWidth < startWidth ? -1 : 1) * rho * travelled)
            return (CGPoint(x: start.x + delta.dx * fraction, y: start.y + delta.dy * fraction), width)
        }
        let coshStart = cosh(startAngle)
        let along = startWidth / (rho * rho * distance) * (coshStart * tanh(rho * travelled + startAngle) - sinh(startAngle))
        return (CGPoint(x: start.x + along * delta.dx, y: start.y + along * delta.dy), startWidth * coshStart / cosh(rho * travelled + startAngle))
    }
}
