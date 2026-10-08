//
//  AnnotationFlattener.swift
//  Reco
//

import CoreGraphics
import CoreImage

/// Bakes a document into a screenshot's pixels (spec 0015), off the main actor: the effects first, through N8's
/// `MaskRenderer`, then the marks drawn over them at the shot's scale, then the crop.
nonisolated enum AnnotationFlattener {

    /// `screenshot` with `document` on it; the same screenshot for an empty document. The HDR picture is dropped: a
    /// marked shot is saved as a PNG.
    @concurrent
    static func flatten(_ document: AnnotationDocument, on screenshot: Screenshot) async throws -> Screenshot {
        guard !document.isEmpty else { return screenshot }
        let scale = screenshot.scale
        var image = try effects(of: document, on: screenshot.image, scale: scale)
        if !document.annotations.allSatisfy(\.isEffect) {
            image = try drawn(document, over: image, scale: scale)
        }
        if let crop = document.crop {
            let pixels = CGRect(x: crop.minX * scale, y: crop.minY * scale, width: crop.width * scale, height: crop.height * scale).integral
            guard let cropped = image.cropping(to: pixels) else { throw CocoaError(.fileReadUnknown) }
            image = cropped
        }
        return Screenshot(image: image, scale: scale, date: screenshot.date, hdrImage: nil, region: screenshot.region)
    }

    /// `image` with the document's blur, pixelate and spotlight marks applied; `image` itself when there are none.
    /// Rectangles are the shot's points, top-left origin; Core Image wants pixels from the bottom-left.
    static func effects(of document: AnnotationDocument, on image: CGImage, scale: CGFloat) throws -> CGImage {
        let effects = document.effects
        guard !effects.isEmpty else { return image }
        let source = CIImage(cgImage: image)
        let height = source.extent.height
        let output = effects.reduce(source) { image, effect in
            let rects = effect.rects.map { rect in
                CGRect(x: rect.minX * scale, y: height - rect.maxY * scale, width: rect.width * scale, height: rect.height * scale).integral
            }
            return MaskRenderer.apply(effect.kind, to: rects, of: image)
        }
        guard let result = context.createCGImage(output, from: source.extent, format: .RGBA8, colorSpace: image.colorSpace) else {
            throw CocoaError(.fileReadUnknown)
        }
        return result
    }

    /// `image` with the document's marks drawn on it, the context scaled so a point is `scale` pixels.
    static func drawn(_ document: AnnotationDocument, over image: CGImage, scale: CGFloat) throws -> CGImage {
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CocoaError(.fileReadUnknown)
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        // Top-left origin in points, as the marks are kept
        context.translateBy(x: 0, y: CGFloat(image.height))
        context.scaleBy(x: scale, y: -scale)
        AnnotationRenderer.draw(document, in: context)
        guard let result = context.makeImage() else { throw CocoaError(.fileReadUnknown) }
        return result
    }

    /// Without colour management, so the pixels outside the effects stay as captured
    private static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])
}
