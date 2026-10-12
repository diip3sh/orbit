//
//  UniformBorders.swift
//  Reco
//

import CoreGraphics

/// Finds the content inside borders of one colour, for Auto Balance (spec 0004, N14): a window shot with desktop
/// around it, or a page with its margins, padded evenly around what's in it.
nonisolated enum UniformBorders {

    /// How far, per channel, a border pixel may be from the corner's colour and still be border: anti-aliased
    /// edges and dithered flat colours are within it.
    static let tolerance = 2

    /// The rows and columns of `pixels` (8 bits per channel, 4 channels, `bytesPerRow` apart) that aren't all the
    /// colour of the top-left pixel, as a rectangle from the top-left corner, in pixels. The whole image when
    /// nothing is trimmed, or when all of it is one colour.
    static func contentRect(width: Int, height: Int, bytesPerRow: Int, pixels: UnsafeBufferPointer<UInt8>) -> CGRect {
        let whole = CGRect(x: 0, y: 0, width: width, height: height)
        guard width > 0, height > 0, let base = pixels.baseAddress else { return whole }
        let border = (base[0], base[1], base[2], base[3])
        func isBorder(_ column: Int, _ row: Int) -> Bool {
            let pixel = base + row * bytesPerRow + column * 4
            return abs(Int(pixel[0]) - Int(border.0)) <= tolerance && abs(Int(pixel[1]) - Int(border.1)) <= tolerance
                && abs(Int(pixel[2]) - Int(border.2)) <= tolerance && abs(Int(pixel[3]) - Int(border.3)) <= tolerance
        }
        func rowIsBorder(_ row: Int) -> Bool {
            (0..<width).allSatisfy { isBorder($0, row) }
        }
        func columnIsBorder(_ column: Int, rows: Range<Int>) -> Bool {
            rows.allSatisfy { isBorder(column, $0) }
        }

        var top = 0
        while top < height, rowIsBorder(top) {
            top += 1
        }
        guard top < height else { return whole }
        var bottom = height
        while bottom > top, rowIsBorder(bottom - 1) {
            bottom -= 1
        }
        var left = 0
        while left < width, columnIsBorder(left, rows: top..<bottom) {
            left += 1
        }
        var right = width
        while right > left, columnIsBorder(right - 1, rows: top..<bottom) {
            right -= 1
        }
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    /// `image`'s content inside its uniform borders, or `image` when it has none.
    static func trimmed(_ image: CGImage) -> CGImage {
        let (width, height) = (image.width, image.height)
        guard width > 0, height > 0, let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let data = context.data else {
            return image
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: context.bytesPerRow * height)
        let content = contentRect(width: width, height: height, bytesPerRow: context.bytesPerRow, pixels: pixels)
        guard content.size != CGSize(width: width, height: height) else { return image }
        return image.cropping(to: content) ?? image
    }
}
