//
//  OverlayImages.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import CoreGraphics
import CoreImage
import CoreText
import CoreVideo
import Foundation

/// The overlays' images, drawn once per render plan and reused by every frame.
nonisolated enum OverlayImages {

    /// A ring of `color`, `diameter` pixels wide, over a faint fill of the same color when `filled`.
    static func ring(diameter: CGFloat, color: CGColor, filled: Bool = true) -> CIImage {
        draw(size: CGSize(width: diameter, height: diameter)) { context in
            let lineWidth = diameter * 0.1
            let circle = CGRect(x: 0, y: 0, width: diameter, height: diameter).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            if filled {
                context.setFillColor(color.copy(alpha: color.alpha * 0.25) ?? color)
                context.fillEllipse(in: circle)
            }
            context.setStrokeColor(color)
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: circle)
        }
    }

    /// Pixels per point of the cursor images below, as sharp as the largest recorded arrow (10×) needs when zoomed.
    private static let cursorScale: CGFloat = 8

    /// The macOS arrow in white with a black outline and a soft shadow, hot spot on its tip.
    static func whiteArrow() -> CursorShapeTrack.Sprite {
        // Points from the arrow's top-left corner: the tip, down the left edge, and round the tail
        let outline = [(0, 0), (0, 16.5), (4, 12.7), (6.6, 18.6), (9.1, 17.5), (6.6, 11.8), (11.7, 11.8)]
            .map { CGPoint(x: $0.0, y: $0.1) }
        let margin: CGFloat = 3
        let size = CGSize(width: (11.7 + 2 * margin) * cursorScale, height: (18.6 + 2 * margin) * cursorScale)
        let image = draw(size: size) { context in
            // The shadow's offset and blur are in pixels whatever the transform: 1 pt down, 2 pt blur, 35%
            context.setShadow(offset: CGSize(width: 0, height: -cursorScale), blur: 2 * cursorScale, color: CGColor(gray: 0, alpha: 0.35))
            context.translateBy(x: 0, y: size.height.rounded(.up))
            context.scaleBy(x: cursorScale, y: -cursorScale)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            context.addLines(between: outline.map { CGPoint(x: $0.x + margin, y: $0.y + margin) })
            context.closePath()
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.setStrokeColor(CGColor(gray: 0, alpha: 1))
            context.setLineWidth(1.25)
            context.setLineJoin(.round)
            context.drawPath(using: .fillStroke)
            context.endTransparencyLayer()
        }
        return CursorShapeTrack.Sprite(
            image: image, hotspot: CGPoint(x: margin * cursorScale, y: image.extent.height - margin * cursorScale), pointsPerPixel: 1 / cursorScale
        )
    }

    /// A translucent grey disc with a white edge, 16 pt wide, hot spot at its centre.
    static func dot() -> CursorShapeTrack.Sprite {
        let diameter = 16 * cursorScale
        let image = draw(size: CGSize(width: diameter, height: diameter)) { context in
            let lineWidth = 1.5 * cursorScale
            let circle = CGRect(x: 0, y: 0, width: diameter, height: diameter).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            context.setFillColor(CGColor(gray: 0.45, alpha: 0.9))
            context.fillEllipse(in: circle)
            context.setStrokeColor(CGColor(gray: 1, alpha: 1))
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: circle)
        }
        return CursorShapeTrack.Sprite(image: image, hotspot: CGPoint(x: diameter / 2, y: diameter / 2), pointsPerPixel: 1 / cursorScale)
    }

    /// `label` in white on a dark rounded rectangle, `height` pixels tall.
    static func chip(label: String, height: CGFloat) -> CIImage {
        guard let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, height * 0.5, nil) else { return .empty() }
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor.white
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: label, attributes: attributes))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let textWidth = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        let padding = height * 0.4
        let size = CGSize(width: textWidth + 2 * padding, height: height)

        return draw(size: size) { context in
            let background = CGPath(
                roundedRect: CGRect(origin: .zero, size: size), cornerWidth: height * 0.25, cornerHeight: height * 0.25, transform: nil
            )
            context.addPath(background)
            context.setFillColor(CGColor(gray: 0, alpha: 0.75))
            context.fillPath()
            context.textPosition = CGPoint(x: padding, y: (height - ascent - descent) / 2 + descent)
            CTLineDraw(line, context)
        }
    }

    /// Color managed, unlike the compositor's: it converts each HDR overlay once, so frames don't have to.
    private static let colorManagedContext = CIContext(options: [.cacheIntermediates: false])

    /// `image`, drawn once in `range`'s encoding, so frames blend it into the video without color
    /// management and it keeps its SDR brightness in HDR. SDR's is the image itself.
    static func encoded(_ image: CIImage, in range: DynamicRange) -> CIImage {
        let extent = image.extent
        guard let colorSpace = range.colorSpace, !extent.isEmpty, !extent.isInfinite else { return image }
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            nil, Int(extent.width), Int(extent.height), kCVPixelFormatType_64RGBAHalf,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer
        )
        guard let buffer else { return image }
        colorManagedContext.render(image, to: buffer, bounds: extent, colorSpace: colorSpace)
        return CIImage(cvPixelBuffer: buffer).transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }

    /// Draws into a transparent sRGB bitmap of `size`, rounded up to whole pixels, with a
    /// bottom-left origin like Core Image's.
    private static func draw(size: CGSize, _ draw: (CGContext) -> Void) -> CIImage {
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: Int(size.width.rounded(.up)), height: Int(size.height.rounded(.up)), bitsPerComponent: 8,
                  bytesPerRow: 0, space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return .empty()
        }
        draw(context)
        return context.makeImage().map { CIImage(cgImage: $0) } ?? .empty()
    }
}
