//
//  OverlayImages+VideoOverlays.swift
//  Reco
//

import CoreGraphics
import CoreImage
import CoreText
import Foundation

/// What ``VideoOverlay``s look like, at the size each shows on the canvas, in sRGB.
nonisolated extension OverlayImages {

    /// `style`'s text wrapped in a box of `size`, centred down it. Text that doesn't fit starts at the top and is cut off
    /// below; the frame can be made larger. Its extent starts at the origin.
    static func text(_ style: TextOverlayStyle, size: CGSize, shorterSide: CGFloat) -> CIImage {
        let fontSize = max(style.size * shorterSide, 1)
        return draw(size: size) { context in
            if style.backgroundOpacity > 0 {
                let radius = min(fontSize / 4, size.width / 2, size.height / 2)
                context.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: radius, cornerHeight: radius, transform: nil))
                context.setFillColor(style.backgroundColor.cgColor.copy(alpha: style.backgroundColor.alpha * style.backgroundOpacity) ?? style.backgroundColor.cgColor)
                context.fillPath()
            }
            guard !style.text.isEmpty, let font = CTFontCreateUIFontForLanguage(style.isBold ? .emphasizedSystem : .system, fontSize, nil) else { return }
            let alignment = switch style.alignment {
            case .left: CTTextAlignment.left
            case .center: CTTextAlignment.center
            case .right: CTTextAlignment.right
            }
            let paragraph = withUnsafePointer(to: alignment) { value in
                var setting = CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: value)
                return CTParagraphStyleCreate(&setting, 1)
            }
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): style.color.cgColor,
                NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph
            ]
            let setter = CTFramesetterCreateWithAttributedString(NSAttributedString(string: style.text, attributes: attributes))
            let (insetX, insetY) = (min(fontSize * 0.4, size.width / 4), min(fontSize * 0.2, size.height / 4))
            let width = size.width - 2 * insetX
            let wanted = CTFramesetterSuggestFrameSizeWithConstraints(
                setter, CFRange(location: 0, length: 0), nil, CGSize(width: width, height: .greatestFiniteMagnitude), nil
            ).height.rounded(.up) + 1
            // Its bottom edge is below the box when it doesn't fit, which the bitmap cuts off
            let room = size.height - 2 * insetY
            let bottom = wanted <= room ? (size.height - wanted) / 2 : size.height - insetY - wanted
            let path = CGPath(rect: CGRect(x: insetX, y: bottom, width: width, height: wanted), transform: nil)
            CTFrameDraw(CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil), context)
        }
    }

    /// `style`'s arrow in a frame of `size`, with `margin` pixels around it for the line and the head to reach past
    /// the frame when an end is on its edge. The extent starts at the origin, `margin` before the frame.
    static func arrow(_ style: ArrowOverlayStyle, size: CGSize, shorterSide: CGFloat) -> (image: CIImage, margin: CGFloat) {
        let width = max(style.strokeWidth * shorterSide, 1)
        let margin = (width * 2).rounded(.up)
        // The frame's top-left fractions, in the image's bottom-left pixels
        let pixel = { (point: CGPoint) in CGPoint(x: margin + point.x * size.width, y: margin + (1 - point.y) * size.height) }
        let (tail, tip) = (pixel(style.start), pixel(style.end))
        let length = hypot(tip.x - tail.x, tip.y - tail.y)
        let image = draw(size: CGSize(width: size.width + 2 * margin, height: size.height + 2 * margin)) { context in
            guard length > 0 else { return }
            let (alongX, alongY) = ((tip.x - tail.x) / length, (tip.y - tail.y) / length)
            // A short arrow is mostly head, whose proportions stay
            let headLength = min(width * 4, length * 0.6)
            let headHalfWidth = headLength * 0.45
            let base = CGPoint(x: tip.x - alongX * headLength, y: tip.y - alongY * headLength)
            context.setFillColor(style.color.cgColor)
            context.setStrokeColor(style.color.cgColor)
            context.setLineWidth(min(width, headHalfWidth))
            context.setLineCap(.round)
            context.move(to: tail)
            context.addLine(to: base)
            context.strokePath()
            context.addLines(between: [
                tip,
                CGPoint(x: base.x - alongY * headHalfWidth, y: base.y + alongX * headHalfWidth),
                CGPoint(x: base.x + alongY * headHalfWidth, y: base.y - alongX * headHalfWidth)
            ])
            context.closePath()
            context.fillPath()
        }
        return (image, margin)
    }

    /// `picture` as large as fits in `size`, keeping its shape, at the pixels it shows. The extent starts at the origin.
    static func fitted(_ picture: CGImage, in size: CGSize) -> CIImage {
        let scale = min(size.width / CGFloat(picture.width), size.height / CGFloat(picture.height))
        let fitted = CGSize(width: max((CGFloat(picture.width) * scale).rounded(), 1), height: max((CGFloat(picture.height) * scale).rounded(), 1))
        return draw(size: fitted) { context in
            context.interpolationQuality = .high
            context.draw(picture, in: CGRect(origin: .zero, size: fitted))
        }
    }
}
