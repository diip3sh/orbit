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
            for index in 0..<plan.clickEffect.ringCount {
                if let progress = plan.clickEffect.progress(ofRing: index, atAge: (time - click.time) / plan.clickDuration) {
                    image = ring(for: click, progress: progress, plan: plan).composited(over: image)
                }
            }
        }
        // Clicks are on the content, so they zoom with it and move onto the canvas; the chip doesn't zoom
        let placements = placements(at: time, plan: plan)
        image = placements.count == 1 ? placed(image, by: placements[0], plan: plan) : summed(placements.map { placed(image, by: $0, plan: plan) })
        // The cursor is placed after, so it's drawn from its full-resolution image
        if let path = plan.cursor, let sprite = plan.cursorShapes.sprite(at: time), let drawn = cursor(sprite, path: path, at: time, plan: plan) {
            image = drawn.composited(over: image)
        }
        if let (chip, opacity) = KeystrokeChip.visible(in: plan.keystrokes, at: time) {
            image = keystroke(chip, opacity: opacity, plan: plan).composited(over: image)
        }
        return image.cropped(to: plan.canvas.videoFrame)
    }

    /// How many output pixels of travel each blur sample covers. Slower parts of a move need fewer samples, and
    /// each costs about 0.7 ms at 4K (see CLAUDE.md, editor phase 4); ``RenderPlan/maximumBlurSamples`` caps them.
    static let blurPixelsPerSample = 2.0

    /// The video's corners must travel this far, in output pixels, across the shutter for a frame to blur.
    /// The camera's spring stops within 0.04 px of its target at 4K, so a settled camera never does.
    static let blurThreshold = 0.5

    /// The cursor blurs from this far, in output pixels.
    static let cursorBlurThreshold = 1.0

    /// Where the video sits at `time`: zoomed to the camera's view, and on the canvas.
    private static func placement(at time: Double, plan: RenderPlan) -> CGAffineTransform {
        transform(to: plan.camera.viewport(at: time), size: plan.videoSize).concatenating(plan.canvas.videoTransform)
    }

    /// The placements to average for the frame at `time`: only the one at `time` when the shutter is closed
    /// or the video's corners move less than ``blurThreshold`` while it's open, so a frame without camera
    /// motion is drawn exactly as without blur. Otherwise one per ``blurPixelsPerSample`` the corners travel,
    /// from 2 to ``RenderPlan/maximumBlurSamples``, evenly spaced across the shutter and centred on `time`.
    static func placements(at time: Double, plan: RenderPlan) -> [CGAffineTransform] {
        let (width, height) = (plan.videoSize.width, plan.videoSize.height)
        let corners = [CGPoint.zero, CGPoint(x: width, y: 0), CGPoint(x: 0, y: height), CGPoint(x: width, y: height)]
        let times = sampleTimes(at: time, plan: plan, threshold: blurThreshold) { time in
            let placement = placement(at: time, plan: plan)
            return corners.map { $0.applying(placement) }
        }
        return times.map { placement(at: $0, plan: plan) }
    }

    /// The times to draw for a frame at `time`: `[time]`, or the samples across the shutter when what
    /// `points` returns for its opening and closing, matched, are `threshold` or more apart.
    private static func sampleTimes(at time: Double, plan: RenderPlan, threshold: Double, points: (Double) -> [CGPoint]) -> [Double] {
        guard plan.shutter > 0 else { return [time] }
        let (opening, closing) = (time - plan.shutter / 2, time + plan.shutter / 2)
        let travel = zip(points(opening), points(closing)).map { hypot($1.x - $0.x, $1.y - $0.y) }.max() ?? 0
        guard travel >= threshold else { return [time] }
        let count = min(max(Int((travel / blurPixelsPerSample).rounded(.up)), 2), plan.maximumBlurSamples)
        return (0..<count).map { time + plan.shutter * ((Double($0) + 0.5) / Double(count) - 0.5) }
    }

    /// The mean of `samples`: each at its share of the alpha (premultiplied, so colour follows), added.
    private static func summed(_ samples: [CIImage]) -> CIImage {
        let weight = 1 / Double(samples.count)
        let weighted = samples.map { $0.fading(to: weight) }
        return weighted.dropFirst().reduce(weighted[0]) { sum, sample in
            sample.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: sum])
        }
    }

    /// The click's ring `progress` of the way, growing from the effect's start size with an ease-out while it fades.
    private static func ring(for click: ClickMarker, progress: Double, plan: RenderPlan) -> CIImage {
        let growth = 1 - pow(1 - progress, 3)
        let start = plan.clickEffect.startScale
        let diameter = click.diameter * (start + (1 - start) * growth)
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
        return image.cropped(to: CGRect(origin: .zero, size: plan.videoSize)).clampedToExtent()
            .transformed(by: placement, highQualityDownsample: plan.downsamplesSmoothly)
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

    /// The cursor's image with its hot spot on the path, moved and magnified with the video, or `nil`
    /// while it's hidden. While it moves, the mean of the image at samples across the shutter, summed
    /// before it's composited so Core Image draws it over the frame once.
    private static func cursor(_ sprite: CursorShapeTrack.Sprite, path: CursorPath, at time: Double, plan: RenderPlan) -> CIImage? {
        let opacity = path.opacity(at: time)
        guard opacity > 0 else { return nil }
        let times = sampleTimes(at: time, plan: plan, threshold: cursorBlurThreshold) {
            [path.position(at: $0).applying(placement(at: $0, plan: plan))]
        }
        let images = times.map { cursorImage(sprite, path: path, at: $0, placement: placement(at: $0, plan: plan)) }
        let image = images.count == 1 ? images[0] : summed(images)
        return opacity < 1 ? image.fading(to: opacity) : image
    }

    private static func cursorImage(_ sprite: CursorShapeTrack.Sprite, path: CursorPath, at time: Double, placement: CGAffineTransform) -> CIImage {
        let position = path.position(at: time).applying(placement)
        let scale = path.scale(at: time) * placement.a * sprite.pointsPerPixel
        let placement = CGAffineTransform(translationX: -sprite.hotspot.x, y: -sprite.hotspot.y)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: position.x, y: position.y))
        // Images recorded at up to 10× are scaled down a lot, which plain sampling would alias
        return sprite.image.transformed(by: placement, highQualityDownsample: true)
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
