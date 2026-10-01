//
//  BackgroundImageLoader.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Foundation
import ImageIO

/// Keeps and reads the picture chosen for the canvas's background. The sandbox gives access to a
/// chosen file only until the app quits, so the project keeps a security-scoped bookmark to it.
nonisolated enum BackgroundImageLoader {

    /// Pictures are read at most this many pixels on their longer side, a 4K frame's.
    static let maximumSize = 4096

    /// A bookmark that opens `url`, chosen by the user, after the app relaunches.
    static func bookmark(for url: URL) throws -> Data {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// The picture `bookmark` opens, upright and in sRGB like the overlays, or `nil` when it's gone
    /// or unreadable.
    @concurrent
    static func image(from bookmark: Data) async -> CGImage? {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumSize
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options),
              let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        // Frames are composited without color management, so the picture's colors are converted here
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}
