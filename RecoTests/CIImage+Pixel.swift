//
//  CIImage+Pixel.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import CoreImage

extension CIImage {

    private static let context = CIContext()
    private static let unmanagedContext = CIContext(options: [.workingColorSpace: NSNull()])

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

    /// The red, green, blue and alpha of the pixel at `point` as stored, without color
    /// management: an HDR frame's encoded values.
    func values(at point: CGPoint) -> [Float] {
        var pixel = [Float](repeating: 0, count: 4)
        Self.unmanagedContext.render(
            self, toBitmap: &pixel, rowBytes: 16, bounds: CGRect(origin: point, size: CGSize(width: 1, height: 1)), format: .RGBAf, colorSpace: nil
        )
        return pixel
    }

    /// The largest red value of any pixel, as stored.
    var brightestRed: Float {
        let maximum = applyingFilter("CIAreaMaximum", parameters: [kCIInputExtentKey: CIVector(cgRect: extent)])
        return maximum.values(at: maximum.extent.origin)[0]
    }
}
