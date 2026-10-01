//
//  ImageDownsampler.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics

/// Draws a smaller copy of an image off the main actor, for previews.
nonisolated enum ImageDownsampler {

    /// `image` with its longer side at most `maxPixelSize` (never enlarged), or `nil` if it can't be drawn.
    @concurrent
    static func thumbnail(of image: CGImage, maxPixelSize: CGFloat) async -> CGImage? {
        let scale = maxPixelSize / CGFloat(max(image.width, image.height))
        guard scale < 1 else { return image }

        let width = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(image.height) * scale).rounded()))
        // Keeps the capture's colour space (sRGB or Display P3); anything else is drawn in sRGB
        let colorSpace = image.colorSpace?.model == .rgb ? image.colorSpace : CGColorSpace(name: CGColorSpace.sRGB)
        guard let colorSpace, let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
