//
//  MatteFill.swift
//  Reco
//

import CoreGraphics

/// A live take's matte as the element's coverage, not its paint: where it is, so the take shows
/// there whatever the page draws later. Supabase's partner search is a translucent field (alpha
/// 0.13) in a faint border, so its paint was mostly its placeholder's letters, and the typed text
/// showed only where those letters had been.
nonisolated enum MatteFill {

    /// Pixels fainter than this, of 255, aren't the element's: page noise under its box.
    static let unpainted: UInt8 = 3

    /// Below half coverage a pixel lets the outside through: an outline's soft outer edge keeps its
    /// alpha, while a glyph's soft edge inside the outline is filled.
    static let solid: UInt8 = 128

    /// `alpha` (one byte per pixel, rows top to bottom) as coverage: scaled so the element's typical
    /// paint (the median painted pixel) is opaque, then every pixel the image's border can't reach
    /// through pixels below ``solid`` made opaque.
    static func filled(alpha: [UInt8], width: Int, height: Int) -> [UInt8] {
        var counts = [Int](repeating: 0, count: 256)
        for value in alpha {
            counts[Int(value)] += 1
        }
        let painted = counts[Int(unpainted)...].reduce(0, +)
        var body = 255
        var seen = 0
        for value in Int(unpainted)...255 {
            seen += counts[value]
            if seen * 2 >= painted {
                body = value
                break
            }
        }
        let coverage = alpha.map { UInt8(min(Int($0) * 255 / max(body, 1), 255)) }

        var outside = [Bool](repeating: false, count: coverage.count)
        var pending: [Int] = []
        func visit(_ index: Int) {
            if !outside[index], coverage[index] < solid {
                outside[index] = true
                pending.append(index)
            }
        }
        for column in 0..<width {
            visit(column)
            visit((height - 1) * width + column)
        }
        for row in 0..<height {
            visit(row * width)
            visit(row * width + width - 1)
        }
        while let index = pending.popLast() {
            let (column, row) = (index % width, index / width)
            if column > 0 { visit(index - 1) }
            if column < width - 1 { visit(index + 1) }
            if row > 0 { visit(index - width) }
            if row < height - 1 { visit(index + width) }
        }
        return coverage.indices.map { outside[$0] ? coverage[$0] : 255 }
    }

    /// `image`'s alpha as coverage (``filled(alpha:width:height:)``); `nil` if it can't be drawn.
    static func filled(_ image: CGImage) -> CGImage? {
        let (width, height) = (image.width, image.height)
        var alpha = [UInt8](repeating: 0, count: width * height)
        let drew = alpha.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }
        let mask = filled(alpha: alpha, width: width, height: height)
        // White with the mask as its alpha, premultiplied: the renderer only reads the alpha
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for (index, value) in mask.enumerated() {
            for channel in 0..<4 {
                pixels[index * 4 + channel] = value
            }
        }
        return pixels.withUnsafeMutableBytes { bytes in
            CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
    }
}
