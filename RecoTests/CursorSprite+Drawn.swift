//
//  CursorSprite+Drawn.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import Reco

extension InputTelemetry.CursorSprite {

    /// A cursor image of `pixels`, drawn by `draw` with a bottom-left origin, `size` points big
    /// with its hot spot at `hotspot` points from its top-left corner.
    static func drawn(pixels: CGSize, size: CGSize, hotspot: CGPoint = .zero, id: Int = 0, _ draw: (CGContext) -> Void) -> Self {
        let data = NSMutableData()
        if let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
           let context = CGContext(
               data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
           ),
           let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) {
            draw(context)
            if let image = context.makeImage() {
                CGImageDestinationAddImage(destination, image, nil)
                CGImageDestinationFinalize(destination)
            }
        }
        return .init(id: id, kind: nil, size: size, hotspot: hotspot, png: data as Data)
    }
}
