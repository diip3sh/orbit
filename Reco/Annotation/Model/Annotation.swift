//
//  Annotation.swift
//  Reco
//

import CoreGraphics
import Foundation

/// One mark on a screenshot (spec 0015): its shape in the shot's points from the top-left corner, its colour and
/// line width. Pure, so the live canvas and the flattened PNG draw it the same way.
nonisolated struct Annotation: Equatable, Identifiable, Sendable {

    nonisolated enum Shape: Equatable, Sendable {
        case arrow(start: CGPoint, end: CGPoint)
        case line(start: CGPoint, end: CGPoint)
        case rectangle(CGRect)
        case ellipse(CGRect)
        /// `origin` is the top-left of the text.
        case text(String, origin: CGPoint)
        /// A freehand stroke, at least one point.
        case highlight([CGPoint])
        /// A numbered disc; the number is its place among the steps, given by the document.
        case step(center: CGPoint)
        case blur(CGRect)
        case pixelate(CGRect)
        case spotlight(CGRect)
    }

    var id = UUID()
    var shape: Shape
    var color: RGBAColor
    /// Points; the highlighter, text and step discs are sized from it.
    var lineWidth: Double

    /// Whether the mark changes the shot's pixels (through `MaskRenderer`) rather than drawing over them.
    var isEffect: Bool {
        switch shape {
        case .blur, .pixelate, .spotlight: true
        default: false
        }
    }

    /// The effect's rectangle, for the effect marks.
    var effectRect: CGRect? {
        switch shape {
        case .blur(let rect), .pixelate(let rect), .spotlight(let rect): rect
        default: nil
        }
    }

    /// The text's point size for a line width: 8× it, so Regular text is 32 pt.
    static func fontSize(for lineWidth: Double) -> CGFloat {
        lineWidth * 8
    }

    /// A step disc's diameter for a line width: Regular gives 28 pt, the size of a toolbar button.
    static func stepDiameter(for lineWidth: Double) -> CGFloat {
        lineWidth * 7
    }

    /// The highlighter's stroke width for a line width.
    static func highlightWidth(for lineWidth: Double) -> CGFloat {
        lineWidth * 6
    }

    /// The text's size when drawn, for hit testing and the field: `lines` of `fontSize`, each about 0.6 em per
    /// character, which is near the system font's average.
    static func textSize(_ text: String, lineWidth: Double) -> CGSize {
        let fontSize = fontSize(for: lineWidth)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let longest = lines.map(\.count).max() ?? 0
        return CGSize(width: max(CGFloat(longest) * fontSize * 0.6, fontSize), height: CGFloat(max(lines.count, 1)) * fontSize * 1.2)
    }

    /// The area the mark covers, for hit testing and the selection outline; a line's or arrow's is its ends' box
    /// grown by its width.
    var bounds: CGRect {
        switch shape {
        case .arrow(let start, let end), .line(let start, let end):
            return CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
                .insetBy(dx: -lineWidth * 2, dy: -lineWidth * 2)
        case .rectangle(let rect), .ellipse(let rect):
            return rect.standardized.insetBy(dx: -lineWidth / 2, dy: -lineWidth / 2)
        case .blur(let rect), .pixelate(let rect), .spotlight(let rect):
            return rect.standardized
        case .text(let text, let origin):
            return CGRect(origin: origin, size: Self.textSize(text, lineWidth: lineWidth))
        case .highlight(let points):
            let half = Self.highlightWidth(for: lineWidth) / 2
            return points.reduce(CGRect(origin: points[0], size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
                .insetBy(dx: -half, dy: -half)
        case .step(let center):
            let radius = Self.stepDiameter(for: lineWidth) / 2
            return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        }
    }

    /// Whether `point` is on the mark: inside its bounds, and for a line, arrow or highlight near the stroke itself.
    func contains(_ point: CGPoint) -> Bool {
        guard bounds.contains(point) else { return false }
        switch shape {
        case .arrow(let start, let end), .line(let start, let end):
            return Self.distance(from: point, toSegment: start, end) <= max(lineWidth * 2, 6)
        case .highlight(let points):
            let reach = max(Self.highlightWidth(for: lineWidth) / 2, 6)
            return zip(points, points.dropFirst()).contains { Self.distance(from: point, toSegment: $0, $1) <= reach }
                || (points.count == 1 && hypot(point.x - points[0].x, point.y - points[0].y) <= reach)
        default:
            return true
        }
    }

    /// The mark moved by `delta`.
    func moved(by delta: CGSize) -> Annotation {
        var moved = self
        let shift = { (point: CGPoint) in CGPoint(x: point.x + delta.width, y: point.y + delta.height) }
        switch shape {
        case .arrow(let start, let end): moved.shape = .arrow(start: shift(start), end: shift(end))
        case .line(let start, let end): moved.shape = .line(start: shift(start), end: shift(end))
        case .rectangle(let rect): moved.shape = .rectangle(rect.offsetBy(dx: delta.width, dy: delta.height))
        case .ellipse(let rect): moved.shape = .ellipse(rect.offsetBy(dx: delta.width, dy: delta.height))
        case .text(let text, let origin): moved.shape = .text(text, origin: shift(origin))
        case .highlight(let points): moved.shape = .highlight(points.map(shift))
        case .step(let center): moved.shape = .step(center: shift(center))
        case .blur(let rect): moved.shape = .blur(rect.offsetBy(dx: delta.width, dy: delta.height))
        case .pixelate(let rect): moved.shape = .pixelate(rect.offsetBy(dx: delta.width, dy: delta.height))
        case .spotlight(let rect): moved.shape = .spotlight(rect.offsetBy(dx: delta.width, dy: delta.height))
        }
        return moved
    }

    /// The distance from `point` to the segment `start`–`end`.
    static func distance(from point: CGPoint, toSegment start: CGPoint, _ end: CGPoint) -> CGFloat {
        let (deltaX, deltaY) = (end.x - start.x, end.y - start.y)
        let lengthSquared = deltaX * deltaX + deltaY * deltaY
        guard lengthSquared > 0 else { return hypot(point.x - start.x, point.y - start.y) }
        let share = min(max(((point.x - start.x) * deltaX + (point.y - start.y) * deltaY) / lengthSquared, 0), 1)
        return hypot(point.x - (start.x + share * deltaX), point.y - (start.y + share * deltaY))
    }
}
