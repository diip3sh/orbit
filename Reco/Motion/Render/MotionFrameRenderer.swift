//
//  MotionFrameRenderer.swift
//  Reco
//

import CoreImage
import CoreVideo

/// Draws one frame of a motion plan: the single place where a motion video's pixels are decided,
/// for the preview, the export and the golden-frame tests alike.
///
/// Lookups into the plan and a small Core Image graph per layer: each plane projected through the
/// camera with `CIPerspectiveTransform`, blurred, faded and shadowed, farthest first.
nonisolated enum MotionFrameRenderer {

    /// The frame at `time` seconds into the video, in output pixels from Core Image's bottom-left
    /// origin. `frames` are the live layers' takes at that time; a live layer without one isn't drawn.
    static func image(at time: Double, plan: MotionPlan, frames: [MotionPlan.LayerKey: CIImage] = [:]) -> CIImage {
        let bounds = CGRect(origin: .zero, size: plan.outputSize)
        let sceneIndex = plan.sceneIndex(at: time)
        let (scene, sceneTime) = plan.scene(at: time)
        var frame = CIImage(color: plan.background).cropped(to: bounds)
        for placement in plan.placements(of: scene, at: sceneTime) {
            let layer = scene.layers[placement.layer]
            let image: CIImage
            if let live = layer.live {
                guard let take = frames[MotionPlan.LayerKey(scene: sceneIndex, layer: placement.layer)] else { continue }
                image = liveImage(take, live: live, at: sceneTime)
            } else {
                guard let layerImage = layer.image else { continue }
                image = layerImage
            }
            frame = drawn(image, layer: layer, at: placement, plan: plan).composited(over: frame)
        }
        return frame.cropped(to: bounds)
    }

    /// Draws the frame at `time` into `buffer`, without color management: `context` must have none.
    static func draw(at time: Double, plan: MotionPlan, frames: [MotionPlan.LayerKey: CIImage] = [:], into buffer: CVPixelBuffer, context: CIContext) throws {
        let destination = CIRenderDestination(pixelBuffer: buffer)
        destination.colorSpace = nil
        _ = try context.startTask(toRender: image(at: time, plan: plan, frames: frames), to: destination).waitUntilCompleted()
    }

    /// A take's frame with its cursor at `time` in the take, inside the element's painted shape. The
    /// cursor is clipped there with the frame, so the layer keeps its size.
    private static func liveImage(_ frame: CIImage, live: MotionPlan.Live, at time: Double) -> CIImage {
        let bounds = frame.extent
        var image = frame
        let time = min(time, live.duration)
        if let path = live.cursor, let sprite = live.cursorShapes.sprite(at: time), path.opacity(at: time) > 0 {
            let position = path.position(at: time)
            let scale = path.scale(at: time) * sprite.pointsPerPixel
            let placement = CGAffineTransform(translationX: -sprite.hotspot.x, y: -sprite.hotspot.y)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: position.x - live.origin.x + bounds.minX, y: position.y - live.origin.y + bounds.minY))
            // Images recorded at up to 10× are scaled down a lot, which plain sampling would alias
            let cursor = sprite.image.transformed(by: placement, highQualityDownsample: true)
            let opacity = path.opacity(at: time)
            image = (opacity < 1 ? cursor.fading(to: opacity) : cursor).composited(over: image)
        }
        let box = (live.matte ?? MotionPlan.roundedRectangle(size: bounds.size, radius: live.radius, scale: 1))
            .transformed(by: CGAffineTransform(translationX: bounds.minX, y: bounds.minY))
        return image.cropped(to: bounds).applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: box])
    }

    /// The layer's image on its quad, with its blur, opacity and shadow.
    private static func drawn(_ image: CIImage, layer: MotionPlan.Layer, at placement: MotionPlan.Placement, plan: MotionPlan) -> CIImage {
        var drawn = projected(image, to: placement.corners, plan: plan)
        let blur = placement.blur * plan.outputScale
        if blur >= 0.3 {
            drawn = drawn.applyingGaussianBlur(sigma: blur)
        }
        if placement.opacity < 1 {
            drawn = drawn.fading(to: placement.opacity)
        }
        guard let shadowImage = layer.shadowImage, let corners = placement.shadowCorners, let shadow = layer.shadow else { return drawn }
        // Cast down the canvas, as far as the layer is scaled
        let offset = shadow.offset * placement.scale
        var cast = projected(shadowImage, to: corners.map { CGPoint(x: $0.x, y: $0.y + offset) }, plan: plan)
        if placement.opacity < 1 {
            cast = cast.fading(to: placement.opacity)
        }
        return drawn.composited(over: cast)
    }

    /// `image` with its corners on `corners`, given in canvas points from the top-left.
    private static func projected(_ image: CIImage, to corners: [CGPoint], plan: MotionPlan) -> CIImage {
        // Canvas points, top-left origin, to output pixels, bottom-left origin
        let output = corners.map { CGPoint(x: $0.x * plan.outputScale, y: (plan.canvas.height - $0.y) * plan.outputScale) }
        return image.applyingFilter("CIPerspectiveTransform", parameters: [
            "inputTopLeft": CIVector(cgPoint: output[0]),
            "inputTopRight": CIVector(cgPoint: output[1]),
            "inputBottomRight": CIVector(cgPoint: output[2]),
            "inputBottomLeft": CIVector(cgPoint: output[3])
        ])
    }
}
