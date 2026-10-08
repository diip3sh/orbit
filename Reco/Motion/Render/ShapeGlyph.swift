//
//  ShapeGlyph.swift
//  Reco
//

import CoreGraphics
import CoreImage

/// A triangle or a glyph shape drawn once into a bitmap at the scale it's shown: motion design's particles and icons
/// (spec 0014). Glyphs are lines with round ends on a unit square, like a UI's own icons.
nonisolated enum ShapeGlyph {

    /// A glyph's line width as a share of its shorter side, without a ``ShapeContent/stroke``.
    static let lineWidth = 0.1

    static func image(of shape: ShapeContent, scale: Double) -> CIImage? {
        let width = max(Int((shape.size.width * scale).rounded()), 1)
        let height = max(Int((shape.size.height * scale).rounded()), 1)
        guard let drawing = path(of: shape.kind), let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // A unit square, y down, over the whole bitmap
        context.translateBy(x: 0, y: Double(height))
        context.scaleBy(x: Double(width), y: -Double(height))
        let color = CGColor(srgbRed: shape.color.red, green: shape.color.green, blue: shape.color.blue, alpha: shape.color.alpha)
        context.setFillColor(color)
        context.setStrokeColor(color)
        let side = min(shape.size.width, shape.size.height)
        context.setLineWidth((shape.stroke ?? side * lineWidth) / side)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(drawing.path)
        context.drawPath(using: drawing.mode)
        return context.makeImage().map { CIImage(cgImage: $0) }
    }

    /// A kind's outline on the unit square and how it's painted; `nil` for a rectangle, which is generated.
    private static func path(of kind: ShapeContent.Kind) -> (path: CGPath, mode: CGPathDrawingMode)? {
        let path = CGMutablePath()
        let lines = { (points: [(Double, Double)]) in path.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) }) }
        switch kind {
        case .rectangle:
            return nil
        case .triangle:
            lines([(0.5, 0), (1, 0.87), (0, 0.87)])
            path.closeSubpath()
            return (path, .fill)
        case .play:
            lines([(0.3, 0.2), (0.82, 0.5), (0.3, 0.8)])
            path.closeSubpath()
            return (path, .fillStroke)
        case .pause:
            path.addRoundedRect(in: CGRect(x: 0.26, y: 0.2, width: 0.16, height: 0.6), cornerWidth: 0.04, cornerHeight: 0.04)
            path.addRoundedRect(in: CGRect(x: 0.58, y: 0.2, width: 0.16, height: 0.6), cornerWidth: 0.04, cornerHeight: 0.04)
            return (path, .fill)
        case .plus:
            lines([(0.2, 0.5), (0.8, 0.5)])
            lines([(0.5, 0.2), (0.5, 0.8)])
        case .check:
            lines([(0.22, 0.53), (0.42, 0.72), (0.78, 0.32)])
        case .cross:
            lines([(0.25, 0.25), (0.75, 0.75)])
            lines([(0.75, 0.25), (0.25, 0.75)])
        case .arrow:
            lines([(0.2, 0.5), (0.8, 0.5)])
            lines([(0.56, 0.26), (0.8, 0.5), (0.56, 0.74)])
        case .search:
            path.addEllipse(in: CGRect(x: 0.18, y: 0.18, width: 0.5, height: 0.5))
            lines([(0.61, 0.61), (0.82, 0.82)])
        }
        return (path, .stroke)
    }
}
