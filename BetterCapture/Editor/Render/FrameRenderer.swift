//
//  FrameRenderer.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import CoreImage

/// Draws one output frame: the single place where the editor decides pixels, for the preview and
/// the export alike.
///
/// Lookups into the plan and a small Core Image graph; nothing is simulated or allocated per frame.
nonisolated enum FrameRenderer {

    /// Draws the effects in `plan` over a source frame.
    /// - Parameters:
    ///   - frame: The recording's frame at `time`.
    ///   - time: Source time, in seconds.
    static func render(_ frame: CIImage, at time: Double, plan: RenderPlan) -> CIImage {
        var image = frame
        for click in ClickMarker.active(in: plan.clicks, at: time, duration: plan.clickDuration) {
            image = ring(for: click, at: time, plan: plan).composited(over: image)
        }
        // Clicks are on the content, so they zoom with it; the chip stays where it is
        let viewport = plan.camera.viewport(at: time)
        image = zoomed(image, to: viewport, size: plan.videoSize)
        // The cursor is placed after zooming, so it's drawn from its full-resolution image
        if let path = plan.cursor, let sprite = plan.cursorShapes.sprite(at: time),
           let drawn = cursor(sprite, path: path, at: time, viewport: viewport, size: plan.videoSize) {
            image = drawn.composited(over: image)
        }
        if let (chip, opacity) = KeystrokeChip.visible(in: plan.keystrokes, at: time) {
            image = keystroke(chip, opacity: opacity, plan: plan).composited(over: image)
        }
        return image
    }

    /// The click's ring, growing from 40% of its size with an ease-out while it fades.
    private static func ring(for click: ClickMarker, at time: Double, plan: RenderPlan) -> CIImage {
        let progress = (time - click.time) / plan.clickDuration
        let growth = 1 - pow(1 - progress, 3)
        let diameter = click.diameter * (0.4 + 0.6 * growth)
        let scale = diameter / plan.clickRing.extent.width
        let placement = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: click.position.x - diameter / 2, y: click.position.y - diameter / 2))
        return plan.clickRing.transformed(by: placement).fading(to: 1 - progress)
    }

    /// The part of `image` in `viewport`, magnified to fill the frame. The whole frame is left as
    /// it is, so frames without zoom stay pixel for pixel the source's.
    private static func zoomed(_ image: CIImage, to viewport: CameraPath.Viewport, size: CGSize) -> CIImage {
        guard viewport.scale > 1 else { return image }
        // Clamped to the frame, so its edge pixels aren't blended with what's around it
        let frame = CGRect(origin: .zero, size: size)
        return image.cropped(to: frame).clampedToExtent().transformed(by: transform(to: viewport, size: size)).cropped(to: frame)
    }

    /// Maps the frame's Core Image pixels to the output's: the part in `viewport` fills it.
    private static func transform(to viewport: CameraPath.Viewport, size: CGSize) -> CGAffineTransform {
        // The view's bottom-left corner in Core Image space
        let origin = CGPoint(
            x: (viewport.center.x - 0.5 / viewport.scale) * size.width,
            y: (1 - viewport.center.y - 0.5 / viewport.scale) * size.height
        )
        return CGAffineTransform(translationX: -origin.x, y: -origin.y).concatenating(CGAffineTransform(scaleX: viewport.scale, y: viewport.scale))
    }

    /// The cursor's image with its hot spot on the path, magnified with the view, or `nil` while
    /// it's hidden.
    private static func cursor(
        _ sprite: CursorShapeTrack.Sprite, path: CursorPath, at time: Double, viewport: CameraPath.Viewport, size: CGSize
    ) -> CIImage? {
        let opacity = path.opacity(at: time)
        guard opacity > 0 else { return nil }
        let position = path.position(at: time).applying(transform(to: viewport, size: size))
        let scale = path.scale(at: time) * viewport.scale * sprite.pointsPerPixel
        let placement = CGAffineTransform(translationX: -sprite.hotspot.x, y: -sprite.hotspot.y)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: position.x, y: position.y))
        // Images recorded at up to 10× are scaled down a lot, which plain sampling would alias
        let image = sprite.image.transformed(by: placement, highQualityDownsample: true)
        return opacity < 1 ? image.fading(to: opacity) : image
    }

    /// The chip, centred at the bottom of the video.
    private static func keystroke(_ chip: KeystrokeChip, opacity: Double, plan: RenderPlan) -> CIImage {
        let image = plan.chipImages[chip.image]
        let placement = CGAffineTransform(
            translationX: ((plan.videoSize.width - image.extent.width) / 2).rounded(), y: (image.extent.height * 0.8).rounded()
        )
        return image.transformed(by: placement).fading(to: opacity)
    }
}

private extension CIImage {

    /// The image with its alpha multiplied by `opacity`.
    nonisolated func fading(to opacity: Double) -> CIImage {
        applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)])
    }
}
