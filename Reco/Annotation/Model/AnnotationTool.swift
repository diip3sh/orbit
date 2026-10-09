//
//  AnnotationTool.swift
//  Reco
//

import CoreGraphics

/// The tool strip's tools, and what a drag or click with each one makes.
nonisolated enum AnnotationTool: String, CaseIterable, Sendable {
    case select, arrow, line, rectangle, ellipse, text, highlighter, step, blur, pixelate, spotlight, crop

    var title: String {
        switch self {
        case .select: "Select"
        case .arrow: "Arrow"
        case .line: "Line"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .text: "Text"
        case .highlighter: "Highlighter"
        case .step: "Step"
        case .blur: "Blur"
        case .pixelate: "Pixelate"
        case .spotlight: "Spotlight"
        case .crop: "Crop"
        }
    }

    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .arrow: "arrow.up.right"
        case .line: "line.diagonal"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .text: "textformat"
        case .highlighter: "highlighter"
        case .step: "1.circle"
        case .blur: "drop"
        case .pixelate: "squareshape.split.3x3"
        case .spotlight: "light.max"
        case .crop: "crop"
        }
    }

    /// The key that picks the tool, as in most drawing apps.
    var shortcut: Character {
        switch self {
        case .select: "v"
        case .arrow: "a"
        case .line: "l"
        case .rectangle: "r"
        case .ellipse: "o"
        case .text: "t"
        case .highlighter: "h"
        case .step: "n"
        case .blur: "b"
        case .pixelate: "p"
        case .spotlight: "s"
        case .crop: "c"
        }
    }

    /// Tools that place a mark with a click instead of a drag.
    var placesOnClick: Bool {
        self == .text || self == .step
    }

    /// Whether the tool's mark takes the colour; effects and the crop have none.
    var usesColor: Bool {
        switch self {
        case .select, .arrow, .line, .rectangle, .ellipse, .text, .highlighter, .step: true
        case .blur, .pixelate, .spotlight, .crop: false
        }
    }

    /// The shape a drag from `start` to `end` makes, or a click at `start` for the tools that place; nil for Select
    /// and Crop, which make no mark, and for a drag too small to mean one.
    func shape(from start: CGPoint, to end: CGPoint) -> Annotation.Shape? {
        switch self {
        case .select, .crop: return nil
        case .text: return .text("", origin: start)
        case .step: return .step(center: start)
        case .highlighter: return .highlight([start, end])
        default:
            guard hypot(end.x - start.x, end.y - start.y) >= AnnotationDocument.minimumSize else { return nil }
            return draggedShape(from: start, to: end)
        }
    }

    private func draggedShape(from start: CGPoint, to end: CGPoint) -> Annotation.Shape? {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
        switch self {
        case .arrow: return .arrow(start: start, end: end)
        case .line: return .line(start: start, end: end)
        case .rectangle: return .rectangle(rect)
        case .ellipse: return .ellipse(rect)
        case .blur: return .blur(rect)
        case .pixelate: return .pixelate(rect)
        case .spotlight: return .spotlight(rect)
        case .select, .crop, .text, .step, .highlighter: return nil
        }
    }
}

/// The strip's colours and line widths.
nonisolated enum AnnotationStyle {

    /// Red first, since most marks point something out.
    static let colors: [RGBAColor] = [
        RGBAColor(red: 1, green: 0.23, blue: 0.19, alpha: 1),
        RGBAColor(red: 1, green: 0.58, blue: 0, alpha: 1),
        RGBAColor(red: 1, green: 0.84, blue: 0.04, alpha: 1),
        RGBAColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1),
        RGBAColor(red: 0, green: 0.48, blue: 1, alpha: 1),
        RGBAColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1),
        RGBAColor(red: 1, green: 1, blue: 1, alpha: 1),
        RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
    ]

    /// Thin, Regular, Bold.
    static let lineWidths: [Double] = [2, 4, 8]

    /// The highlighter's alpha.
    static let highlightAlpha = 0.4
}
