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

    /// The most samples a frame blurred by motion is averaged from, as the editor's: what plays in
    /// real time for the preview; an export takes twice as many.
    static let previewBlurSamples = 8
    static let exportBlurSamples = 16

    /// The frame at `time` seconds into the video, in output pixels from Core Image's bottom-left
    /// origin. `frames` are the live layers' takes at that time; a live layer without one isn't drawn.
    ///
    /// While the planes move, it's the frame a 180° shutter would see: samples across half a frame,
    /// one per ``FrameRenderer/blurSampleSpacing`` pixels the planes travel. A whip without it read
    /// as a jump (spec 0012, L1c); a still frame is drawn once.
    static func image(at time: Double, plan: MotionPlan, frames: [MotionPlan.LayerKey: CIImage] = [:]) -> CIImage {
        let shutter = 0.5 / Double(plan.frameRate)
        let offsets = FrameRenderer.blurOffsets(
            distance: travel(at: time, across: shutter, plan: plan), most: plan.isPreview ? previewBlurSamples : exportBlurSamples
        )
        let scene = plan.scenes[plan.sceneIndex(at: time)]
        // Inside the scene: a shutter open across a cut would blend the two shots
        let times = offsets.map { min(max(time + $0 * shutter, scene.start), scene.start + scene.duration - 1e-6) }
        return FrameRenderer.average(times.map { still(at: $0, plan: plan, frames: frames) })
    }

    /// How far the planes on screen at `time` move while a shutter `shutter` seconds long is open, in
    /// output pixels: the most any of their corners travels.
    private static func travel(at time: Double, across shutter: Double, plan: MotionPlan) -> Double {
        let (scene, sceneTime) = plan.scene(at: time)
        let closing = Dictionary(plan.placements(of: scene, at: sceneTime + shutter / 2).map { ($0.layer, $0.corners) }) { first, _ in first }
        let travel = plan.placements(of: scene, at: sceneTime - shutter / 2).map { opening in
            closing[opening.layer].map { corners in
                zip(opening.corners, corners).map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? 0
            } ?? 0
        }
        return (travel.max() ?? 0) * plan.outputScale
    }

    /// The frame at `time` as a shutter open for an instant sees it.
    private static func still(at time: Double, plan: MotionPlan, frames: [MotionPlan.LayerKey: CIImage]) -> CIImage {
        let bounds = CGRect(origin: .zero, size: plan.outputSize)
        let index = plan.sceneIndex(at: time)
        let sceneTime = time - plan.scenes[index].start
        let background = CIImage(color: plan.background).cropped(to: bounds)
        var frame = sceneImage(index, at: sceneTime, plan: plan, frames: frames)
        // Under a transition, the scene before goes on from its end
        if let transition = plan.scenes[index].transition, index > 0, sceneTime < transition.duration {
            let previous = sceneImage(index - 1, at: plan.scenes[index - 1].duration + sceneTime, plan: plan, frames: frames)
            let progress = transition.progress(at: sceneTime)
            switch transition.seam {
            case .push:
                let width = bounds.width
                frame = frame.transformed(by: CGAffineTransform(translationX: width * (1 - progress), y: 0))
                    .composited(over: previous.transformed(by: CGAffineTransform(translationX: -width * progress, y: 0)))
            default:
                frame = previous.fading(to: 1 - progress).composited(over: frame)
            }
        }
        return frame.composited(over: background).cropped(to: bounds)
    }

    /// Draws the frame at `time` into `buffer`, without color management: `context` must have none.
    static func draw(at time: Double, plan: MotionPlan, frames: [MotionPlan.LayerKey: CIImage] = [:], into buffer: CVPixelBuffer, context: CIContext) throws {
        let destination = CIRenderDestination(pixelBuffer: buffer)
        destination.colorSpace = nil
        _ = try context.startTask(toRender: image(at: time, plan: plan, frames: frames), to: destination).waitUntilCompleted()
    }

    /// A scene's layers at `time` in it, blurred as its camera is, over its field.
    private static func sceneImage(_ index: Int, at time: Double, plan: MotionPlan, frames: [MotionPlan.LayerKey: CIImage]) -> CIImage {
        let scene = plan.scenes[index]
        var image = CIImage.empty()
        for placement in plan.placements(of: scene, at: time) {
            let layer = scene.layers[placement.layer]
            var content: CIImage
            if let live = layer.live {
                guard let take = frames[MotionPlan.LayerKey(scene: index, layer: placement.layer)] else { continue }
                content = liveImage(take, live: live, at: time)
            } else {
                guard let layerImage = layer.image else { continue }
                content = layerImage
            }
            if let reveal = layer.reveal {
                content = revealed(content, of: layer, by: reveal, at: time)
            }
            if let region = layer.region, case let dim = layer.value(.dim, at: time), dim > 0 {
                if let focusedImage = layer.focusedImage {
                    // Drawn once at the most it dims; part of the way there, faded over the layer
                    content = focusedImage.fading(to: min(dim / layer.mostDim, 1)).composited(over: content)
                } else {
                    content = MotionPlan.focused(content, on: region, dim: dim, height: layer.size.height)
                }
            }
            image = drawn(content, layer: layer, at: placement, time: time, plan: plan).composited(over: image)
        }
        let bounds = CGRect(origin: .zero, size: plan.outputSize)
        // On the video's clock, so a field runs on across a cut to a scene with the same one
        let field = FieldRenderer.image(
            scene.field, palette: scene.palette, at: scene.start + time, size: plan.outputSize, preview: plan.isPreview,
            view: fieldView(of: scene, at: time, plan: plan)
        )
        let blur = scene.cameraValue(.blur, at: time) * plan.outputScale
        guard blur >= 0.3 else { return image.composited(over: field) }
        return image.clampedToExtent().applyingGaussianBlur(sigma: blur).cropped(to: bounds).composited(over: field)
    }

    /// How far a field moves with the camera: this share of what the planes do, as ground far behind
    /// them would. Pinned to the frame, it read as a wallpaper behind a whip (spec 0012, L1b).
    static let fieldParallax = 0.15

    /// Where a scene's camera puts its field at `time`: shifted by a share of the camera's look away
    /// from the canvas's middle, as the planes are at its zoom, and zoomed by that share in log space.
    private static func fieldView(of scene: MotionPlan.Scene, at time: Double, plan: MotionPlan) -> CGAffineTransform {
        let zoom = max(scene.cameraValue(.scale, at: time), 0.01)
        let pixels = fieldParallax * zoom * plan.outputScale
        let shift = CGVector(
            dx: (scene.cameraValue(.positionX, at: time) - plan.canvas.width / 2) * pixels,
            dy: (scene.cameraValue(.positionY, at: time) - plan.canvas.height / 2) * pixels
        )
        let middle = CGPoint(x: plan.outputSize.width / 2, y: plan.outputSize.height / 2)
        let scale = pow(zoom, fieldParallax)
        // Core Image's y is up: looking further down the canvas moves the field up the frame
        return CGAffineTransform(translationX: middle.x - shift.dx, y: middle.y + shift.dy).scaledBy(x: scale, y: scale).translatedBy(x: -middle.x, y: -middle.y)
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

    /// The layer's image on its quad, with its blur, depth of field, opacity and shadow.
    private static func drawn(_ image: CIImage, layer: MotionPlan.Layer, at placement: MotionPlan.Placement, time: Double, plan: MotionPlan) -> CIImage {
        var drawn = projected(image, to: placement.corners, plan: plan)
        var blur = placement.blur
        if let most = placement.defocus.map(abs).max(), let least = placement.defocus.map(abs).min() {
            if most - least < 0.5 {
                // Parallel to the lens: one blur across it
                blur += least
            } else if most * plan.outputScale >= 0.3 {
                let mask = projected(defocusMask(placement.defocus, over: image.extent), to: placement.corners, plan: plan)
                drawn = drawn.applyingFilter("CIMaskedVariableBlur", parameters: ["inputMask": mask, kCIInputRadiusKey: most * plan.outputScale])
            }
        }
        blur *= plan.outputScale
        if blur >= 0.3 {
            drawn = drawn.applyingGaussianBlur(sigma: blur)
        }
        if placement.opacity < 1 {
            drawn = drawn.fading(to: placement.opacity)
        }
        guard let shadowImage = layer.shadowImage, let corners = placement.shadowCorners, let shadow = layer.shadow else { return drawn }
        // Cast down the canvas, as far as the layer is scaled and lifted
        let strength = max(layer.value(.shadow, at: time), 0)
        let offset = shadow.offset * placement.scale * strength
        var cast = projected(shadowImage, to: corners.map { CGPoint(x: $0.x, y: $0.y + offset) }, plan: plan)
        if placement.opacity * min(strength, 1) < 1 {
            cast = cast.fading(to: placement.opacity * min(strength, 1))
        }
        return drawn.composited(over: cast)
    }

    /// White as far out of focus as the layer gets, black where it's sharp, over an image's `extent`,
    /// from the blur at its corners (top-left, top-right, bottom-right, bottom-left). Blur changes
    /// linearly across a plane, so it's two gradients away from the line in focus.
    private static func defocusMask(_ defocus: [Double], over extent: CGRect) -> CIImage {
        let size = extent.size
        // Change per pixel across and down, in Core Image's space (y up)
        let across = (defocus[1] - defocus[0]) / size.width
        let down = (defocus[3] - defocus[0]) / size.height
        let gradient = CGVector(dx: across, dy: -down)
        let squared = gradient.dx * gradient.dx + gradient.dy * gradient.dy
        let most = defocus.map(abs).max() ?? 1
        // The top-left corner is at (0, height); along the gradient from there to where the blur is 0
        let topLeft = CGPoint(x: extent.minX, y: extent.maxY)
        let sharp = CGPoint(x: topLeft.x - defocus[0] * gradient.dx / squared, y: topLeft.y - defocus[0] * gradient.dy / squared)
        let reach = CGVector(dx: most * gradient.dx / squared, dy: most * gradient.dy / squared)
        let side = { (sign: Double) -> CIImage in
            CIFilter(name: "CILinearGradient", parameters: [
                "inputPoint0": CIVector(cgPoint: sharp),
                "inputPoint1": CIVector(x: sharp.x + sign * reach.dx, y: sharp.y + sign * reach.dy),
                "inputColor0": CIColor.black,
                "inputColor1": CIColor.white
            ])?.outputImage ?? CIImage(color: .black)
        }
        return side(1).applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: side(-1)])
            .cropped(to: extent)
    }

    /// A text layer's parts shown as far as `reveal` has got at `time`: each whole, or partly, by
    /// its style. Its image is drawn at its raster scale, rounded up to whole pixels.
    private static func revealed(_ image: CIImage, of layer: MotionPlan.Layer, by reveal: TextReveal, at time: Double) -> CIImage {
        let (scale, height, parts) = (layer.rasterScale, layer.size.height, layer.parts)
        let pixels = { (rect: CGRect) in
            // Taller than the line, for accents and descenders that reach past it
            let rect = rect.insetBy(dx: 0, dy: -rect.height * 0.15)
            return CGRect(x: rect.minX * scale, y: (height - rect.maxY) * scale, width: rect.width * scale, height: rect.height * scale)
        }
        // The layer's whole extent, clear where nothing shows yet: the projection maps the extent to the quad
        var shown = CIImage(color: .clear).cropped(to: image.extent)
        // Parts already shown in full, joined while they're on one line
        var whole: CGRect?
        for (index, part) in parts.enumerated() {
            let progress = reveal.progress(ofPart: index, at: time)
            guard progress > 0 else { break }
            if progress >= 1 {
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
            let piece = image.cropped(to: pixels(part))
            switch reveal.style {
            case .type:
                break
            case .wipe:
                // Sharpens as it fades in: 8% of its line, 9.8 px for a 1080p headline (at most 10 on text)
                shown = piece.applyingGaussianBlur(sigma: (1 - progress) * part.height * 0.08 * scale).fading(to: progress).composited(over: shown)
            case .rise:
                shown = piece.transformed(by: CGAffineTransform(translationX: 0, y: -(1 - progress) * part.height * scale))
                    .cropped(to: pixels(part)).composited(over: shown)
            case .word:
                // Up a quarter of its line, sharpening from 4% of it, as it fades in
                shown = piece.applyingGaussianBlur(sigma: (1 - progress) * part.height * 0.04 * scale)
                    .transformed(by: CGAffineTransform(translationX: 0, y: -(1 - progress) * part.height * 0.25 * scale))
                    .fading(to: progress).composited(over: shown)
            }
        }
        if let run = whole {
            shown = image.cropped(to: pixels(run)).composited(over: shown)
        }
        return shown.cropped(to: image.extent)
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
