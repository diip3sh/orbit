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

    /// The frame at `time` seconds into the video, in output pixels from Core Image's bottom-left origin.
    static func image(at time: Double, plan: MotionPlan) -> CIImage {
        let bounds = CGRect(origin: .zero, size: plan.outputSize)
        let (scene, sceneTime) = plan.scene(at: time)
        var frame = CIImage(color: plan.background).cropped(to: bounds)
        for placement in plan.placements(of: scene, at: sceneTime) {
            let layer = scene.layers[placement.layer]
            guard let image = layer.image else { continue }
            frame = drawn(image, layer: layer, at: placement, plan: plan).composited(over: frame)
        }
        return frame.cropped(to: bounds)
    }

    /// Draws the frame at `time` into `buffer`, without color management: `context` must have none.
    static func draw(at time: Double, plan: MotionPlan, into buffer: CVPixelBuffer, context: CIContext) throws {
        let destination = CIRenderDestination(pixelBuffer: buffer)
        destination.colorSpace = nil
        _ = try context.startTask(toRender: image(at: time, plan: plan), to: destination).waitUntilCompleted()
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
