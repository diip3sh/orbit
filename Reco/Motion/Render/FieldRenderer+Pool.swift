//
//  FieldRenderer+Pool.swift
//  Reco
//

import CoreImage

/// The pool of light (spec 0020): the ground lit by one soft light in the brand's hue, a new place each shot, drifting and
/// following the camera as far ground does; the frame falling off to the ground's colour round it, the UI with it, so the
/// light lies on the product rather than behind it (Linear Agent's black: its edges 0 of 255, its middle 10–36).
nonisolated extension FieldRenderer {

    /// Where each shot's pool lies, as shares of the frame from its top-left, and how far it reaches as a share of the width.
    static let poolSetups: [(place: CGPoint, reach: Double)] = [
        (CGPoint(x: 0.5, y: 0.42), 0.5), (CGPoint(x: 0.62, y: 0.38), 0.45), (CGPoint(x: 0.38, y: 0.5), 0.5), (CGPoint(x: 0.55, y: 0.6), 0.42)
    ]

    /// How far a pool drifts, as a share of the frame, and how fast (radians a second).
    static let poolDrift = (reach: 0.03, rate: 0.2)

    /// How dark the frame's corners fall under the pool, the UI too: a share of their light.
    static let poolCorners = 0.45

    /// The pool's middle at `time`, in output pixels from the bottom-left, and its reach.
    static func poolCentre(at time: Double, size: CGSize, shot: Shot) -> (centre: CGPoint, reach: Double) {
        let setup = poolSetups[shot.index % poolSetups.count]
        let local = time - shot.start
        let across = (setup.place.x + poolDrift.reach * sin(poolDrift.rate * local)) * size.width + groundParallax * shot.shift.dx
        let down = (setup.place.y + poolDrift.reach * cos(poolDrift.rate * 0.8 * local)) * size.height + groundParallax * shot.shift.dy
        return (CGPoint(x: across, y: size.height - down), setup.reach * size.width)
    }

    /// The ground with its pool of light.
    static func pool(palette: FieldPalette, at time: Double, size: CGSize, shot: Shot) -> CIImage {
        let extent = CGRect(origin: .zero, size: size)
        let back = CIColor(red: palette.back.red, green: palette.back.green, blue: palette.back.blue)
        guard let light = palette.colors.first else { return CIImage(color: back).cropped(to: extent) }
        let (centre, reach) = poolCentre(at: time, size: size, shot: shot)
        // Wider than tall, as a light falls on a table
        let gradient = CIFilter(name: "CIGaussianGradient", parameters: [
            "inputCenter": CIVector(x: 0, y: 0), "inputRadius": reach,
            "inputColor0": CIColor(red: light.red, green: light.green, blue: light.blue), "inputColor1": back
        ])?.outputImage?.transformed(by: CGAffineTransform(scaleX: 1, y: 0.7).concatenating(CGAffineTransform(translationX: centre.x, y: centre.y)))
        return (gradient ?? CIImage(color: back)).cropped(to: extent)
    }

    /// `frame` falling off round its pool to ``poolCorners`` of its light.
    static func pooled(_ frame: CIImage, at time: Double, size: CGSize, shot: Shot) -> CIImage {
        let (centre, _) = poolCentre(at: time, size: size, shot: shot)
        let corners = CIColor(red: poolCorners, green: poolCorners, blue: poolCorners)
        guard let falloff = CIFilter(name: "CIGaussianGradient", parameters: [
            "inputCenter": CIVector(x: centre.x, y: centre.y), "inputRadius": hypot(size.width, size.height) * 0.6,
            "inputColor0": CIColor.white, "inputColor1": corners
        ])?.outputImage else { return frame }
        return frame.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: falloff]).cropped(to: frame.extent)
    }
}
