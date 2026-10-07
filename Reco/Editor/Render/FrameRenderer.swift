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

    /// How far apart, in pixels, the samples of a blurred frame are, until there are as many as the
    /// plan allows: close enough that text smears instead of doubling.
    ///
    /// Measured on an M5, Debug, 4K with a ring and a chip, load average 3, mid-zoom: 8 samples
    /// draw in 2.8 ms p50 (1.3 unblurred), and in 7.9 ms on the default canvas (2.8 unblurred); 16
    /// take 5.5 and 12.5 ms, 4 still 2 and 5.6. Only frames in which the camera moves pay it.
    static let blurSampleSpacing = 4.0

    /// The frame with everything on it - clicks, zoom, cursor and keystroke chip - placed on the
    /// canvas and clipped to the video's frame, square-cornered.
    private static func video(_ frame: CIImage, at time: Double, plan: RenderPlan) -> CIImage {
        var image = frame
        for click in ClickMarker.active(in: plan.clicks, at: time, duration: plan.clickDuration) {
            image = ring(for: click, at: time, plan: plan).composited(over: image)
        }
        // Clicks are on the content, so they zoom with it and move onto the canvas; the chip doesn't zoom
        let placement = placement(at: time, plan: plan)
        // While the camera moves, the frame as a shutter open across the move would see it. A view
        // that's still is drawn once, so its pixels stay the source's
        let opening = Self.placement(at: time - plan.cameraShutter / 2, plan: plan)
        let closing = Self.placement(at: time + plan.cameraShutter / 2, plan: plan)
        let corner = CGPoint(x: plan.videoSize.width, y: plan.videoSize.height)
        let moves = blurOffsets(
            distance: max(distance(CGPoint.zero.applying(opening), CGPoint.zero.applying(closing)), distance(corner.applying(opening), corner.applying(closing))),
            most: plan.blurSamples
        )
        let source = image
        image = average(moves.map { placed(source, by: $0 == 0 ? placement : Self.placement(at: time + $0 * plan.cameraShutter, plan: plan), plan: plan) })
        // The cursor is placed after, so it's drawn from its full-resolution image
        if let path = plan.cursor, let sprite = plan.cursorShapes.sprite(at: time), let drawn = cursor(sprite, path: path, at: time, plan: plan) {
            image = drawn.composited(over: image)
        }
        if let (chip, opacity) = KeystrokeChip.visible(in: plan.keystrokes, at: time) {
            image = keystroke(chip, opacity: opacity, plan: plan).composited(over: image)
        }
        return image.cropped(to: plan.canvas.videoFrame)
    }

    /// When a frame whose content moves `distance` pixels while the shutter is open is sampled, as
    /// shares of the shutter from the frame's time: one sample per ``blurSampleSpacing`` pixels, at
    /// most `most`, or just the frame's time when it moves less than half a pixel.
    static func blurOffsets(distance: Double, most: Int) -> [Double] {
        guard distance >= 0.5 else { return [0] }
        let count = min(max(Int((distance / blurSampleSpacing).rounded(.up)), 2), most)
        return (0..<count).map { (Double($0) + 0.5) / Double(count) - 0.5 }
    }

    /// The mean of `images`; the one itself when alone. Shared with motion videos' blur.
    static func average(_ images: [CIImage]) -> CIImage {
        guard images.count > 1 else { return images[0] }
        let shares = images.map { $0.fading(to: 1 / Double(images.count)) }
        return shares.dropFirst().reduce(shares[0]) { $1.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: $0]) }
    }

    private static func distance(_ first: CGPoint, _ second: CGPoint) -> Double {
        hypot(first.x - second.x, first.y - second.y)
    }

    /// Maps the frame's Core Image pixels to the canvas's at source time `time`: zoomed to the
    /// camera's view, then onto the canvas.
    private static func placement(at time: Double, plan: RenderPlan) -> CGAffineTransform {
        transform(to: plan.camera.viewport(at: time), size: plan.videoSize).concatenating(plan.canvas.videoTransform)
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

    /// The cursor's image with its hot spot on the path, moved and magnified with the video, and
    /// smeared along its way across the canvas while the shutter is open, or `nil` while it's hidden.
    private static func cursor(_ sprite: CursorShapeTrack.Sprite, path: CursorPath, at time: Double, plan: RenderPlan) -> CIImage? {
        let opacity = path.opacity(at: time)
        guard opacity > 0 else { return nil }
        // Where the hot spot is on the canvas a share of the shutters from `time`: it moves on the
        // video and with the camera
        let position = { (offset: Double) in
            path.position(at: time + offset * plan.cursorShutter).applying(placement(at: time + offset * plan.cameraShutter, plan: plan))
        }
        let scale = path.scale(at: time) * placement(at: time, plan: plan).a * sprite.pointsPerPixel
        let shape = CGAffineTransform(translationX: -sprite.hotspot.x, y: -sprite.hotspot.y)
            .concatenating(CGAffineTransform(rotationAngle: path.tilt(at: time)))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
        let offsets = plan.cursorShutter > 0 ? blurOffsets(distance: distance(position(-0.5), position(0.5)), most: plan.blurSamples) : [0]
        let image = average(offsets.map { offset in
            let position = position(offset)
            // Images recorded at up to 10× are scaled down a lot, which plain sampling would alias
            return sprite.image.transformed(by: shape.concatenating(CGAffineTransform(translationX: position.x, y: position.y)), highQualityDownsample: true)
        })
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
