//
//  PlannedBubble.swift
//  Reco
//

import CoreImage
import CoreImage.CIFilterBuiltins
import CoreMedia
import CoreVideo

/// The camera bubble as a render plan draws it, its mask and shadow drawn once.
nonisolated struct PlannedBubble: Sendable {

    /// Where the footage starts on the recording's timeline in seconds, the user's adjustment included.
    let offset: Double

    /// At rest on the canvas, in Core Image pixels.
    let rect: CGRect

    /// The coverage of a bubble with its corner at the origin.
    let mask: CIImage

    /// Its shadow, placed the same way, or `nil` without one.
    let shadow: CIImage?

    /// Output seconds with footage to show. The compositor can't be relied on for this: an export's reader keeps
    /// handing it the footage's last frame through the empty time after its end (measured), where the image generator
    /// and the time before its start give none.
    let visibleRanges: [Range<Double>]

    /// The part of the camera's frame shown, as fractions of it from its top-left corner.
    let crop: CGRect
    let isMirrored: Bool
    let shrinksDuringZooms: Bool
    let orientation: CGImagePropertyOrientation

    /// `style`'s bubble in `videoFrame`, or `nil` when it's hidden or there's no footage.
    static func planned(
        _ style: CameraOverlayStyle, footage: CameraFootage?, timeMap: TimeMap, videoFrame: CGRect, dynamicRange: DynamicRange
    ) -> PlannedBubble? {
        guard style.isEnabled, let footage else { return nil }
        let rect = CameraBubbleLayout.rect(of: style, in: videoFrame)
        let radius = style.roundness * rect.width / 2
        let shape = CIFilter.roundedRectangleGenerator()
        shape.extent = CGRect(origin: .zero, size: rect.size)
        shape.radius = Float(radius)
        shape.color = .white
        var shadow: CIImage?
        if style.shadow > 0 {
            let reach = (rect.width * OverlayImages.bubbleShadowReach).rounded()
            shadow = OverlayImages.encoded(OverlayImages.bubbleShadow(side: rect.width, radius: radius, opacity: style.shadow), in: dynamicRange)
                .transformed(by: CGAffineTransform(translationX: -reach, y: -reach))
        }
        let offset = footage.offset + style.timeOffset
        return PlannedBubble(
            offset: offset, rect: rect, mask: shape.outputImage ?? .empty(), shadow: shadow,
            visibleRanges: visibleRanges(of: offset..<offset + footage.timeRange.duration.seconds, timeMap: timeMap),
            crop: VideoCrop.clamped(style.crop), isMirrored: style.isMirrored, shrinksDuringZooms: style.shrinksDuringZooms,
            orientation: footage.orientation
        )
    }

    /// Where `footage`, on the source timeline, shows in the output.
    static func visibleRanges(of footage: Range<Double>, timeMap: TimeMap) -> [Range<Double>] {
        timeMap.outputRanges(ofSource: footage)
    }

    /// A camera frame as the plan draws it. AVFoundation converts an SDR track to the composition's color space for an
    /// HDR compositor (measured in `CameraTrackTests`), so a frame already in `range`'s encoding is used as it comes.
    /// One that isn't is converted here, which draws it once more.
    ///
    /// ponytail: the first SDR frame a reader delivers comes tagged PQ but unconverted (white at 1, then 0.58 from the
    /// next frame on, in 8-bit and 10-bit sources alike), so an HDR export's bubble is too bright for that one frame. A
    /// stateless compositor can't tell it apart; drawing the camera outside AVFoundation's conversion would.
    static func image(of buffer: CVPixelBuffer, in range: DynamicRange) -> CIImage {
        let image = CIImage(cvPixelBuffer: buffer)
        guard let transferFunction = range.transferFunction else { return image }
        let tagged = CVBufferCopyAttachment(buffer, kCVImageBufferTransferFunctionKey, nil) as? String
        return tagged == transferFunction ? image : OverlayImages.encoded(image, in: range)
    }
}

nonisolated extension FrameRenderer {

    /// `image` (on the canvas) under the bubble, or as it is without a camera frame or a bubble. Not blurred: the bubble
    /// doesn't move with the zoom.
    static func bubbled(_ image: CIImage, camera: CIImage?, at time: Double, plan: RenderPlan) -> CIImage {
        guard let bubble = plan.bubble, let camera, bubble.visibleRanges.contains(where: { $0.contains(time) }) else { return image }
        let scale = bubble.shrinksDuringZooms ? CameraBubbleLayout.shrink(atZoom: plan.camera.viewport(at: time).scale) : 1
        let face = filled(bubble, from: camera, smoothly: plan.downsamplesSmoothly)
            .applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputMaskImageKey: bubble.mask])
        let drawn = bubble.shadow.map { face.composited(over: $0) } ?? face
        return drawn.transformed(by: CameraBubbleLayout.placement(of: bubble.rect, scale: scale, in: plan.canvas.videoFrame))
            .composited(over: image)
    }

    /// The square with its corner at the origin, filled from the middle of the crop.
    private static func filled(_ bubble: PlannedBubble, from camera: CIImage, smoothly: Bool) -> CIImage {
        let frame = camera.oriented(bubble.orientation)
        let (extent, side) = (frame.extent, bubble.rect.width)
        let crop = CGRect(
            x: extent.minX + bubble.crop.minX * extent.width, y: extent.minY + (1 - bubble.crop.maxY) * extent.height,
            width: bubble.crop.width * extent.width, height: bubble.crop.height * extent.height
        )
        let scale = side / min(crop.width, crop.height)
        let fill = CGAffineTransform(translationX: -crop.midX, y: -crop.midY)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: side / 2, y: side / 2))
        // Clamped, so the crop's edge pixels aren't blended with what's around them
        let filled = frame.cropped(to: crop).clampedToExtent().transformed(by: fill, highQualityDownsample: smoothly)
        let box = CGRect(x: 0, y: 0, width: side, height: side)
        guard bubble.isMirrored else { return filled.cropped(to: box) }
        return filled.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: side, ty: 0)).cropped(to: box)
    }
}
