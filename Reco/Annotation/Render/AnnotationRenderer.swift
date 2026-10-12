//
//  AnnotationRenderer.swift
//  Reco
//

import CoreGraphics
import CoreText
import Foundation

/// Draws marks with Core Graphics into a context whose unit is the shot's point, origin top-left, y down: the live
/// canvas's (scaled to the display) and the flattened PNG's (scaled to the pixels) alike, so both show the same thing.
nonisolated enum AnnotationRenderer {

    /// Every mark in `document`, in order, the one with `selected`'s id outlined.
    static func draw(_ document: AnnotationDocument, selected: Annotation.ID? = nil, in context: CGContext) {
        for annotation in document.annotations {
            draw(annotation, number: document.stepNumber(of: annotation), in: context)
        }
        if let selected, let annotation = document[selected] {
            drawSelection(around: annotation.bounds, in: context)
        }
    }

    /// One mark; `number` is a step's. Effects draw nothing here: they're in the pixels under the marks.
    static func draw(_ annotation: Annotation, number: Int?, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        let color = annotation.color.cgColor
        let width = annotation.lineWidth
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        switch annotation.shape {
        case .line(let start, let end):
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
        case .arrow(let start, let end):
            drawArrow(from: start, to: end, width: width, in: context)
        case .rectangle(let rect):
            context.stroke(rect.standardized)
        case .ellipse(let rect):
            context.strokeEllipse(in: rect.standardized)
        case .highlight(let points):
            context.setLineWidth(Annotation.highlightWidth(for: width))
            context.setStrokeColor(color.copy(alpha: AnnotationStyle.highlightAlpha) ?? color)
            context.move(to: points[0])
            for point in points.dropFirst() {
                context.addLine(to: point)
            }
            if points.count == 1 {
                context.addLine(to: points[0])
            }
            context.strokePath()
        case .step(let center):
            drawStep(number ?? 0, at: center, diameter: Annotation.stepDiameter(for: width), color: annotation.color, in: context)
        case .text(let text, let origin):
            drawText(text, at: origin, fontSize: Annotation.fontSize(for: width), color: annotation.color, in: context)
        case .blur, .pixelate, .spotlight:
            break
        }
    }

    /// Dims everything outside `crop`, for the canvas while cropping.
    static func drawCropDim(_ crop: CGRect, in size: CGSize, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        let path = CGMutablePath()
        path.addRect(CGRect(origin: .zero, size: size))
        path.addRect(crop)
        context.addPath(path)
        context.setFillColor(CGColor(gray: 0, alpha: 0.5))
        context.fillPath(using: .evenOdd)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.9))
        context.setLineWidth(1)
        context.stroke(crop.insetBy(dx: 0.5, dy: 0.5))
    }

    /// A white line over a black one, so the outline shows on any shot.
    static func drawSelection(around bounds: CGRect, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        let rect = bounds.insetBy(dx: -3, dy: -3)
        context.setLineWidth(3)
        context.setStrokeColor(CGColor(gray: 0, alpha: 0.5))
        context.stroke(rect)
        context.setLineWidth(1)
        context.setStrokeColor(CGColor(gray: 1, alpha: 1))
        context.setLineDash(phase: 0, lengths: [4, 3])
        context.stroke(rect)
    }

    /// The shaft ends under the head, a filled triangle `width × 4` long and `width × 3` across at `to`.
    private static func drawArrow(from start: CGPoint, to end: CGPoint, width: Double, in context: CGContext) {
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > 0 else { return }
        let direction = CGPoint(x: (end.x - start.x) / length, y: (end.y - start.y) / length)
        let headLength = min(width * 4, length)
        let headHalfWidth = width * 1.5
        let base = CGPoint(x: end.x - direction.x * headLength, y: end.y - direction.y * headLength)
        context.move(to: start)
        context.addLine(to: CGPoint(x: end.x - direction.x * headLength * 0.6, y: end.y - direction.y * headLength * 0.6))
        context.strokePath()
        let normal = CGPoint(x: -direction.y, y: direction.x)
        context.move(to: end)
        context.addLine(to: CGPoint(x: base.x + normal.x * headHalfWidth, y: base.y + normal.y * headHalfWidth))
        context.addLine(to: CGPoint(x: base.x - normal.x * headHalfWidth, y: base.y - normal.y * headHalfWidth))
        context.closePath()
        context.fillPath()
    }

    private static func drawStep(_ number: Int, at center: CGPoint, diameter: CGFloat, color: RGBAColor, in context: CGContext) {
        let disc = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        context.fillEllipse(in: disc)
        context.setLineWidth(1)
        context.setStrokeColor(contrasting(color).copy(alpha: 0.5) ?? contrasting(color))
        context.strokeEllipse(in: disc.insetBy(dx: 0.5, dy: 0.5))
        let font = font(size: diameter * 0.55)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(number), attributes: attributes(font: font, color: contrasting(color))))
        let textBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        context.saveGState()
        context.translateBy(x: center.x - textBounds.midX, y: center.y + textBounds.midY)
        context.scaleBy(x: 1, y: -1)
        // The text position is the context's, left wherever the last text ended
        context.textPosition = .zero
        context.setTextDrawingMode(.fill)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    /// Bold system text from `origin` (its top-left), line by line, with a halo in the contrasting colour.
    private static func drawText(_ text: String, at origin: CGPoint, fontSize: CGFloat, color: RGBAColor, in context: CGContext) {
        let font = font(size: fontSize)
        let ascent = CTFontGetAscent(font)
        let lineHeight = fontSize * 1.2
        context.setStrokeColor(contrasting(color).copy(alpha: 0.75) ?? contrasting(color))
        context.setLineWidth(max(fontSize / 12, 1))
        context.setLineJoin(.round)
        for (index, lineText) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(lineText), attributes: attributes(font: font, color: color.cgColor)))
            context.saveGState()
            context.translateBy(x: origin.x, y: origin.y + ascent + CGFloat(index) * lineHeight)
            context.scaleBy(x: 1, y: -1)
            // Drawing moves the text position on, so each pass starts from the origin
            context.textPosition = .zero
            context.setTextDrawingMode(.stroke)
            CTLineDraw(line, context)
            context.textPosition = .zero
            context.setTextDrawingMode(.fill)
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }

    /// Core Text's keys, so no AppKit is needed off the main actor.
    private static func attributes(font: CTFont, color: CGColor) -> [NSAttributedString.Key: Any] {
        [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color]
    }

    /// The bold system font at `size`.
    static func font(size: CGFloat) -> CTFont {
        CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil) ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    }

    /// Black for a light colour, white for a dark one: the halo, a step's number.
    static func contrasting(_ color: RGBAColor) -> CGColor {
        let luminance = 0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue
        return CGColor(gray: luminance > 0.6 ? 0 : 1, alpha: 1)
    }
}
