//
//  MaskRenderer.swift
//  Reco
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// A mask as the renderer draws it: its rectangles in the video's Core Image pixels.
nonisolated struct PlannedMask: Equatable, Sendable {
    /// Source seconds.
    let range: Range<Double>
    let rects: [CGRect]
    let kind: MaskSegment.Kind

    /// `masks` in a `videoSize` video (the crop's size), on whole pixels.
    static func planned(_ masks: [MaskSegment], videoSize: CGSize) -> [PlannedMask] {
        masks.map { mask in
            let rects = mask.rects.map { rect in
                CGRect(
                    x: rect.minX * videoSize.width, y: (1 - rect.maxY) * videoSize.height,
                    width: rect.width * videoSize.width, height: rect.height * videoSize.height
                ).integral
            }
            return PlannedMask(range: mask.range, rects: rects, kind: mask.kind)
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

    /// `image` (the video, in its Core Image pixels) with the mask showing at source time `time` applied.
    static func masked(_ image: CIImage, at time: Double, plan: RenderPlan) -> CIImage {
        guard let mask = plan.masks.active(at: time) else { return image }
        return MaskRenderer.apply(mask.kind, to: mask.rects, of: image)
    }
}

/// Hides rectangles of an image, for the editor's masks and the screenshot card.
nonisolated enum MaskRenderer {

    /// A blur's sigma, as a share of the image's shorter side: 26 px at 2160, past where text can be read.
    static let blur = 0.012

    /// A pixelated cell's side, as a share of the image's shorter side: 43 px at 2160, at least 4.
    static let cell = 0.02

    /// How far each cell's brightness is moved at random, either way. `CIPixellate` gives a cell one pixel's colour
    /// (8 px cells over 4 px strokes came out solid black, measured), and the noise moves it, so pixelation can't be
    /// undone by rendering candidates and matching their cells (as CleanShot's noise prevents).
    static let noise = 0.06

    /// How dark a spotlight makes everything outside it.
    static let spotlightDim = 0.6

    /// `image` with `rects` (in its pixels) hidden by `kind`. Only the rectangles change, except for a spotlight,
    /// which dims the rest.
    static func apply(_ kind: MaskSegment.Kind, to rects: [CGRect], of image: CIImage) -> CIImage {
        let side = min(image.extent.width, image.extent.height)
        switch kind {
        case .blur:
            // Clamped, so the edges of the frame don't blur in black
            let blurred = image.clampedToExtent().applyingGaussianBlur(sigma: side * blur)
            return rects.reduce(image) { blurred.cropped(to: $1).composited(over: $0) }
        case .pixelate:
            let cellSide = max((side * cell).rounded(), 4)
            return rects.reduce(image) { pixelated(image, in: $1, cell: cellSide).composited(over: $0) }
        case .spotlight:
            let dimmed = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: spotlightDim)).composited(over: image).cropped(to: image.extent)
            return rects.reduce(dimmed) { image.cropped(to: $1).composited(over: $0) }
        }
    }

    /// `image` pixelated in cells of `cell` pixels that start at `rect`'s corner, so its edges are whole cells, cut to it.
    private static func pixelated(_ image: CIImage, in rect: CGRect, cell: CGFloat) -> CIImage {
        let pixellate = CIFilter.pixellate()
        pixellate.inputImage = image.clampedToExtent()
        pixellate.scale = Float(cell)
        pixellate.center = rect.origin
        guard let pixelated = pixellate.outputImage else { return image.cropped(to: rect) }
        return noise(cell: cell, origin: rect.origin)
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: pixelated])
            .cropped(to: rect)
    }

    /// One opaque grey per cell from 1 - ``noise`` to 1 + ``noise``, to multiply the cells by. Opaque, since
    /// Core Image premultiplies a filter's output: a grey with alpha 0 would be nothing. The generator is the same
    /// every frame, so the noise holds still.
    private static func noise(cell: CGFloat, origin: CGPoint) -> CIImage {
        let grey = CIVector(x: 2 * noise, y: 0, z: 0, w: 0)
        return CIFilter.randomGenerator().outputImage?
            .samplingNearest()
            .transformed(by: CGAffineTransform(scaleX: cell, y: cell).concatenating(CGAffineTransform(translationX: origin.x, y: origin.y)))
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": grey, "inputGVector": grey, "inputBVector": grey,
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 1 - noise, y: 1 - noise, z: 1 - noise, w: 1)
            ]) ?? .empty()
    }
}
