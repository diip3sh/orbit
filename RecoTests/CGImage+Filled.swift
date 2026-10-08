//
//  CGImage+Filled.swift
//  RecoTests
//
//  Created by Diip3sh on 29.09.26.
//

import CoreGraphics
import Testing

extension CGImage {

    /// An opaque red sRGB image of `width` × `height` pixels
    static func filled(width: Int, height: Int) throws -> CGImage {
        try drawn(width: width, height: height) {
            $0.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            $0.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// An sRGB image of `width` × `height` pixels drawn by `draw`, with a bottom-left origin
    static func drawn(width: Int, height: Int, _ draw: (CGContext) -> Void) throws -> CGImage {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        draw(context)
        return try #require(context.makeImage())
    }
}
