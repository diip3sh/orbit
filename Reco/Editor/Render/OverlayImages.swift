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

    /// A ring of `color`, `diameter` pixels wide, over a faint fill of the same color.
    static func ring(diameter: CGFloat, color: CGColor) -> CIImage {
        draw(size: CGSize(width: diameter, height: diameter)) { context in
            let lineWidth = diameter * 0.1
            let circle = CGRect(x: 0, y: 0, width: diameter, height: diameter).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            context.setFillColor(color.copy(alpha: color.alpha * 0.25) ?? color)
            context.fillEllipse(in: circle)
            context.setStrokeColor(color)
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: circle)
        }
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
