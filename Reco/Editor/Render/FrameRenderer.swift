//
//  FrameRenderer.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import CoreImage
import CoreVideo

/// Draws one output frame: the single place where the editor decides pixels, for the preview and
/// the export alike.
///
/// Lookups into the plan and a small Core Image graph; nothing is simulated or allocated per frame.
nonisolated enum FrameRenderer {

    /// Draws the output frame for source time `time` into `buffer`, region by region, each from
    /// only what shows there (see ``CanvasLayout/regions``), without color management: `context`
    /// must have none. HDR plans' overlays are already in the video's encoding.
    /// - Parameters:
    ///   - frame: The recording's frame at `time`.
    ///   - time: Source time, in seconds.
    static func draw(_ frame: CIImage, at time: Double, plan: RenderPlan, into buffer: CVPixelBuffer, context: CIContext) throws {
        let video = video(frame, at: time, plan: plan)
        let destination = CIRenderDestination(pixelBuffer: buffer)
        destination.colorSpace = nil
        let tasks = try plan.canvas.regions.map { region in
            let image = switch region {
            case .background: plan.canvas.backdrop ?? .empty()
            case .video: video
            case .corner: framed(video, on: plan.canvas)
            }
            return try context.startTask(toRender: image, from: region.rect, to: destination, at: region.rect.origin)
        }
        for task in tasks {
            _ = try task.waitUntilCompleted()
        }
    }

    /// The frame with everything on it - clicks, zoom, cursor and keystroke chip - placed on the
    /// canvas and clipped to the video's frame, square-cornered.
    private static func video(_ frame: CIImage, at time: Double, plan: RenderPlan) -> CIImage {
        var image = frame
        for click in ClickMarker.active(in: plan.clicks, at: time, duration: plan.clickDuration) {
            image = ring(for: click, at: time, plan: plan).composited(over: image)
        }
        // Clicks are on the content, so they zoom with it and move onto the canvas; the chip doesn't zoom
        let placement = transform(to: plan.camera.viewport(at: time), size: plan.videoSize).concatenating(plan.canvas.videoTransform)
        image = placed(image, by: placement, plan: plan)
        // The cursor is placed after, so it's drawn from its full-resolution image
        if let path = plan.cursor, let sprite = plan.cursorShapes.sprite(at: time),
           let drawn = cursor(sprite, path: path, at: time, placement: placement) {
            image = drawn.composited(over: image)
        }
        if let (chip, opacity) = KeystrokeChip.visible(in: plan.keystrokes, at: time) {
            image = keystroke(chip, opacity: opacity, plan: plan).composited(over: image)
        }
        return image.cropped(to: plan.canvas.videoFrame)
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

    /// The frame moved by `placement`, zoomed and onto the canvas, in one resampling so it stays as
    /// sharp as it can. A frame that fills the canvas unzoomed stays pixel for pixel the source's.
    private static func placed(_ image: CIImage, by placement: CGAffineTransform, plan: RenderPlan) -> CIImage {
        guard !placement.isIdentity else { return image }
        // Clamped to the frame, so its edge pixels aren't blended with what's around it
        return image.cropped(to: CGRect(origin: .zero, size: plan.videoSize)).clampedToExtent().transformed(by: placement)
    }

    /// Maps the frame's Core Image pixels to the zoomed frame's: the part in `viewport` fills it.
    private static func transform(to viewport: CameraPath.Viewport, size: CGSize) -> CGAffineTransform {
        guard viewport.scale > 1 else { return .identity }
        // The view's bottom-left corner in Core Image space
        let origin = CGPoint(
            x: (viewport.center.x - 0.5 / viewport.scale) * size.width,
            y: (1 - viewport.center.y - 0.5 / viewport.scale) * size.height
        )
        return CGAffineTransform(translationX: -origin.x, y: -origin.y).concatenating(CGAffineTransform(scaleX: viewport.scale, y: viewport.scale))
    }

    /// The video in its shape over the background.
    private static func framed(_ video: CIImage, on canvas: CanvasLayout) -> CIImage {
        guard let backdrop = canvas.backdrop else { return video }
        guard let mask = canvas.videoMask else { return video.composited(over: backdrop) }
        return video.applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputBackgroundImageKey: backdrop, kCIInputMaskImageKey: mask])
    }

    /// The cursor's image with its hot spot on the path, moved and magnified with the video, or
    /// `nil` while it's hidden.
    private static func cursor(_ sprite: CursorShapeTrack.Sprite, path: CursorPath, at time: Double, placement: CGAffineTransform) -> CIImage? {
        let opacity = path.opacity(at: time)
        guard opacity > 0 else { return nil }
        let position = path.position(at: time).applying(placement)
        let scale = path.scale(at: time) * placement.a * sprite.pointsPerPixel
        let placement = CGAffineTransform(translationX: -sprite.hotspot.x, y: -sprite.hotspot.y)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: position.x, y: position.y))
        // Images recorded at up to 10× are scaled down a lot, which plain sampling would alias
        let image = sprite.image.transformed(by: placement, highQualityDownsample: true)
        return opacity < 1 ? image.fading(to: opacity) : image
    }

    /// The chip, centred at the bottom of the video on the canvas.
    private static func keystroke(_ chip: KeystrokeChip, opacity: Double, plan: RenderPlan) -> CIImage {
        let image = plan.chipImages[chip.image]
        let video = plan.canvas.videoFrame
        let placement = CGAffineTransform(
            translationX: (video.midX - image.extent.width / 2).rounded(), y: (video.minY + image.extent.height * 0.8).rounded()
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
