//
//  TextImage.swift
//  Reco
//

import AppKit
import CoreText

/// A text layer drawn once with Core Text, and where its words and lines are, so a reveal can show
/// part of it without drawing it again.
nonisolated struct TextImage: @unchecked Sendable {

    /// The text at `scale` pixels per canvas pixel; `nil` for empty text.
    let image: CGImage?

    /// The layer's size in canvas pixels.
    let size: CGSize

    /// Each word's and each line's box in canvas pixels from the layer's top-left corner.
    let words: [CGRect]
    let lines: [CGRect]

    init(_ content: TextContent, scale: Double) {
        let attributed = NSAttributedString(string: content.text, attributes: [
            .font: Self.font(for: content),
            .foregroundColor: NSColor(cgColor: content.color.cgColor) ?? .white,
            .paragraphStyle: Self.paragraphStyle(for: content.alignment)
        ])
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let constraint = CGSize(width: content.width ?? .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        let fitted = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil, constraint, nil)
        let size = CGSize(width: (content.width ?? fitted.width).rounded(.up), height: fitted.height.rounded(.up))
        self.size = size

        let frame = CTFramesetterCreateFrame(framesetter, CFRange(), CGPath(rect: CGRect(origin: .zero, size: size), transform: nil), nil)
        let lines = CTFrameGetLines(frame) as? [CTLine] ?? []
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(), &origins)

        // Boxes from the top-left corner: Core Text's origins are baselines from the bottom-left
        var lineBoxes: [CGRect] = []
        var wordBoxes: [CGRect] = []
        let text = content.text as NSString
        for (line, origin) in zip(lines, origins) {
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            let top = size.height - origin.y - ascent
            lineBoxes.append(CGRect(x: origin.x, y: top, width: width, height: ascent + descent))
            let range = CTLineGetStringRange(line)
            text.enumerateSubstrings(in: NSRange(location: range.location, length: range.length), options: .byWords) { _, wordRange, _, _ in
                let start = CTLineGetOffsetForStringIndex(line, wordRange.location, nil)
                let end = CTLineGetOffsetForStringIndex(line, NSMaxRange(wordRange), nil)
                wordBoxes.append(CGRect(x: origin.x + start, y: top, width: end - start, height: ascent + descent))
            }
        }
        self.lines = lineBoxes
        words = wordBoxes

        let pixels = CGSize(width: (size.width * scale).rounded(.up), height: (size.height * scale).rounded(.up))
        guard pixels.width >= 1, pixels.height >= 1, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            image = nil
            return
        }
        context.scaleBy(x: scale, y: scale)
        CTFrameDraw(frame, context)
        image = context.makeImage()
    }

    /// SF Pro, New York or SF Mono at the content's size and weight.
    private static func font(for content: TextContent) -> NSFont {
        let weight: NSFont.Weight = switch content.weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
        let design: NSFontDescriptor.SystemDesign = switch content.face {
        case .sans: .default
        case .serif: .serif
        case .mono: .monospaced
        }
        let system = NSFont.systemFont(ofSize: content.size, weight: weight)
        return system.fontDescriptor.withDesign(design).flatMap { NSFont(descriptor: $0, size: content.size) } ?? system
    }

    private static func paragraphStyle(for alignment: TextContent.Alignment) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = switch alignment {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
        return style
    }
}
