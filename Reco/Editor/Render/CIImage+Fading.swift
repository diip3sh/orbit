//
//  CIImage+Fading.swift
//  Reco
//

import CoreImage

extension CIImage {

    /// The image with its alpha multiplied by `opacity`. Alpha only: `CIColorMatrix` works on
    /// unpremultiplied color, so scaling RGB too would darken by the share squared.
    nonisolated func fading(to opacity: Double) -> CIImage {
        applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)])
    }
}
