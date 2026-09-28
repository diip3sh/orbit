//
//  ImageDownsampler.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Foundation
import ImageIO

/// Decodes a thumbnail of an image file, off the main actor, without ever holding the full-size image.
nonisolated enum ImageDownsampler {

    /// The image at `url` with its longer side at most `maxPixelSize`, decoded now, or `nil` if unreadable.
    @concurrent
    static func thumbnail(of url: URL, maxPixelSize: CGFloat) async -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
