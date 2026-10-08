//
//  MotionFrameRenderer+Reveal.swift
//  Reco
//

import CoreImage

/// Text revealed part by part: typed, wiped, rising, words, letters springing in (spec 0011, 0014).
nonisolated extension MotionFrameRenderer {

    /// A text layer's parts shown as far as `reveal` has got at `time`: each whole, or partly, by
    /// its style. Its image is drawn at its raster scale, rounded up to whole pixels.
    static func revealed(_ image: CIImage, of layer: MotionPlan.Layer, by reveal: TextReveal, at time: Double) -> CIImage {
        let pixels = { (rect: CGRect) in revealPixels(of: rect, in: layer) }
        // The layer's whole extent and the room its letters move in, clear where nothing shows yet: the projection maps the
        // extent to the quad around it
        let room = layer.revealRoom
        let extent = image.extent.insetBy(dx: -room.width * layer.rasterScale, dy: -room.height * layer.rasterScale)
        var shown = CIImage(color: .clear).cropped(to: extent)
        // Parts already shown in full, joined while they're on one line
        var whole: CGRect?
        for (index, part) in layer.parts.enumerated() {
            let fraction = reveal.fraction(ofPart: index, at: time)
            guard fraction > 0 else { break }
            if fraction >= 1 {
                if let run = whole, abs(run.minY - part.minY) < 0.5 {
                    whole = run.union(part)
                } else {
                    if let run = whole {
                        shown = image.cropped(to: pixels(run)).composited(over: shown)
                    }
                    whole = part
                }
                continue
            }
            let progress = reveal.progress(ofPart: index, at: time)
            if let piece = partway(image.cropped(to: pixels(part)), part: part, of: layer, style: reveal.style, progress: (progress, fraction)) {
                shown = piece.composited(over: shown)
            }
        }
        if let run = whole {
            shown = image.cropped(to: pixels(run)).composited(over: shown)
        }
        if reveal.style == .kinetic, layer.accent != nil {
            shown = kinetic(shown, image: image, of: layer, by: reveal, at: time)
        }
        return shown.cropped(to: extent)
    }

    /// The room letters spring through around their text, in lines across and down: from 0.7 of a line below to a
    /// quarter above at 1.35× (``TextReveal/letterPose(_:)``), each piece 0.15 of a line taller than its line.
    static let letterRoom = CGSize(width: 0.5, height: 1)

    /// A part's rectangle (canvas pixels from the layer's top-left) in its image's pixels, taller than its line for
    /// accents and descenders that reach past it.
    static func revealPixels(of rect: CGRect, in layer: MotionPlan.Layer) -> CGRect {
        let (scale, height) = (layer.rasterScale, layer.size.height)
        let rect = rect.insetBy(dx: 0, dy: -rect.height * 0.15)
        return CGRect(x: rect.minX * scale, y: (height - rect.maxY) * scale, width: rect.width * scale, height: rect.height * scale)
    }

    /// A part on its way in, `progress` of the way (eased, then not), as its style shows it; `nil` for a style that
    /// shows a part only whole.
    private static func partway(
        _ piece: CIImage, part: CGRect, of layer: MotionPlan.Layer, style: TextReveal.Style, progress: (eased: Double, fraction: Double)
    ) -> CIImage? {
        let (eased, line, scale) = (progress.eased, part.height, layer.rasterScale)
        switch style {
        case .type, .kinetic:
            return nil
        case .wipe:
            // Sharpens as it fades in: 8% of its line, 9.8 px for a 1080p headline (at most 10 on text)
            return piece.applyingGaussianBlur(sigma: (1 - eased) * line * 0.08 * scale).fading(to: eased)
        case .rise:
            return piece.transformed(by: CGAffineTransform(translationX: 0, y: -(1 - eased) * line * scale)).cropped(to: revealPixels(of: part, in: layer))
        case .word:
            // Up a quarter of its line, sharpening from 4% of it, as it fades in
            return piece.applyingGaussianBlur(sigma: (1 - eased) * line * 0.04 * scale)
                .transformed(by: CGAffineTransform(translationX: 0, y: -(1 - eased) * line * 0.25 * scale)).fading(to: eased)
        case .letter:
            // Grown about its middle and moved up from below, into the room around the layer
            let pose = TextReveal.letterPose(progress.fraction)
            let middle = CGPoint(x: piece.extent.midX, y: piece.extent.midY)
            let placed = CGAffineTransform(translationX: -middle.x, y: -middle.y)
                .concatenating(CGAffineTransform(scaleX: pose.scale, y: pose.scale))
                .concatenating(CGAffineTransform(translationX: middle.x, y: middle.y - pose.below * line * scale))
            return piece.transformed(by: placed).fading(to: pose.opacity)
        }
    }
}
