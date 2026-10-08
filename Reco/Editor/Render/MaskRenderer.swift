//
//  MaskRenderer.swift
//  Reco
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// A mask as the renderer draws it: its rectangle in the video's Core Image pixels.
nonisolated struct PlannedMask: Equatable, Sendable {
    /// Source seconds.
    let range: Range<Double>
    let rect: CGRect
    let kind: MaskSegment.Kind

    /// `masks` in a `videoSize` video (the crop's size), on whole pixels.
    static func planned(_ masks: [MaskSegment], videoSize: CGSize) -> [PlannedMask] {
        masks.map { mask in
            let rect = CGRect(
                x: mask.rect.minX * videoSize.width, y: (1 - mask.rect.maxY) * videoSize.height,
                width: mask.rect.width * videoSize.width, height: mask.rect.height * videoSize.height
            )
            return PlannedMask(range: mask.range, rect: rect.integral, kind: mask.kind)
        }
    }
}

nonisolated extension [PlannedMask] {

    /// The mask showing at source time `time`; masks are sorted and apart, so there's at most one.
    func active(at time: Double) -> PlannedMask? {
        let index = partitioningIndex { $0.range.upperBound > time }
        return index < count && self[index].range.contains(time) ? self[index] : nil
    }
}

nonisolated extension FrameRenderer {

    /// A blur's sigma, as a share of the video's shorter side: 26 px at 2160, past where text can be read.
    static let maskBlur = 0.012

    /// A pixelated cell's side, as a share of the video's shorter side: 43 px at 2160, at least 4.
    static let maskCell = 0.02

    /// How far each cell's brightness is moved at random, either way: the cells' colours are no longer the averages
    /// of what's under them, so pixelation can't be undone by matching candidates against them (as CleanShot does).
    static let maskNoise = 0.06

    /// How dark a spotlight makes everything outside it.
    static let spotlightDim = 0.6

    /// `image` (the video, in its Core Image pixels) with the mask showing at source time `time` applied. Only the
    /// mask's rectangle changes, except for a spotlight, which dims the rest.
    static func masked(_ image: CIImage, at time: Double, plan: RenderPlan) -> CIImage {
        guard let mask = plan.masks.active(at: time) else { return image }
        let side = min(plan.videoSize.width, plan.videoSize.height)
        switch mask.kind {
        case .blur:
            // Clamped, so the edges of the frame don't blur in black
            return image.clampedToExtent().applyingGaussianBlur(sigma: side * maskBlur).cropped(to: mask.rect).composited(over: image)
        case .pixelate:
            let cell = max((side * maskCell).rounded(), 4)
            let pixellate = CIFilter.pixellate()
            pixellate.inputImage = image.clampedToExtent()
            pixellate.scale = Float(cell)
            // Cells start at the rectangle's corner, so its edges are whole cells
            pixellate.center = mask.rect.origin
            guard let pixelated = pixellate.outputImage else { return image }
            return noise(cell: cell, origin: mask.rect.origin)
                .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: pixelated])
                .cropped(to: mask.rect)
                .composited(over: image)
        case .spotlight:
            let dimmed = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: spotlightDim)).composited(over: image).cropped(to: image.extent)
            return image.cropped(to: mask.rect).composited(over: dimmed)
        }
    }

    /// One opaque grey per cell from 1 - ``maskNoise`` to 1 + ``maskNoise``, to multiply the cells by. Opaque, since
    /// Core Image premultiplies a filter's output: a grey with alpha 0 would be nothing. The generator is the same
    /// every frame, so the noise holds still.
    private static func noise(cell: CGFloat, origin: CGPoint) -> CIImage {
        let grey = CIVector(x: 2 * maskNoise, y: 0, z: 0, w: 0)
        return CIFilter.randomGenerator().outputImage?
            .samplingNearest()
            .transformed(by: CGAffineTransform(scaleX: cell, y: cell).concatenating(CGAffineTransform(translationX: origin.x, y: origin.y)))
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": grey, "inputGVector": grey, "inputBVector": grey,
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 1 - maskNoise, y: 1 - maskNoise, z: 1 - maskNoise, w: 1)
            ]) ?? .empty()
    }
}
