//
//  CIImage+Pixel.swift
//  BetterCaptureTests
//
//  Created by Diip3sh on 26.09.26.
//

import CoreImage

extension CIImage {

    private static let context = CIContext()

    /// The 8-bit sRGB red, green, blue and alpha of the pixel whose bottom-left corner is at
    /// `point`, in Core Image space.
    func pixel(at point: CGPoint) -> [UInt8] {
        var pixel = [UInt8](repeating: 0, count: 4)
        Self.context.render(
            self, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(origin: point, size: CGSize(width: 1, height: 1)),
            format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        return pixel
    }
}
