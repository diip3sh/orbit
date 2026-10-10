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

    /// The most samples a frame blurred by motion is averaged from: what plays in real time for the
    /// preview, as the editor's; an export takes as many as the film's whip needed (16 left it in ghosts
    /// 20 px apart), one every 3 px a point travels.
    static let previewBlurSamples = 8
    static let exportBlurSamples = 96
    static let exportBlurSpacing = 3.0

    /// The frame at `time` seconds into the video, in output pixels from Core Image's bottom-left
    /// origin. `frames` are the live layers' takes at that time; a live layer without one isn't drawn.
    ///
    /// While the planes move, it's the frame a 180° shutter would see: samples across half a frame,
    /// one per ``FrameRenderer/blurSampleSpacing`` pixels the planes travel. A whip without it read
    /// as a jump (spec 0012, L1c); a still frame is drawn once.
    static func image(at time: Double, plan: MotionPlan, frames: [MotionPlan.LayerKey: CIImage] = [:]) -> CIImage {
        let shutter = 0.5 / Double(plan.frameRate)
        let offsets = FrameRenderer.blurOffsets(
            distance: travel(at: time, across: shutter, plan: plan), most: plan.isPreview ? previewBlurSamples : exportBlurSamples,
            spacing: plan.isPreview ? FrameRenderer.blurSampleSpacing : exportBlurSpacing
        )
        let scene = plan.scenes[plan.sceneIndex(at: time)]
        // Inside the scene: a shutter open across a cut would blend the two shots
        let times = offsets.map { min(max(time + $0 * shutter, scene.start), scene.start + scene.duration - 1e-6) }
        let frame = FrameRenderer.average(times.map { still(at: $0, sharpAt: time, plan: plan, frames: frames) })
        // Satin's grain goes over the whole frame, its UI too, once a frame
        guard scene.field == .satin else { return frame }
        return FieldRenderer.grained(frame, index: Int((time * Double(plan.frameRate)).rounded()), size: plan.outputSize)
    }

    /// How far the planes and pointers on screen at `time` move while a shutter `shutter` seconds long is open, in
    /// output pixels: the most any of their corners or tips travels. Layers drawn sharp don't count.
    private static func travel(at time: Double, across shutter: Double, plan: MotionPlan) -> Double {
        let (scene, sceneTime) = plan.scene(at: time)
        let (opens, closes) = (sceneTime - shutter / 2, sceneTime + shutter / 2)
        let moving = { (time: Double) in plan.placements(of: scene, at: time).filter { !scene.layers[$0.layer].isSharp } }
        let closing = Dictionary(moving(closes).map { ($0.layer, $0.corners) }) { first, _ in first }
        let travel = moving(opens).map { opening in
            closing[opening.layer].map { corners in
                zip(opening.corners, corners).map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? 0
            } ?? 0
        }
        let pointers = zip(pointerTips(of: scene, at: opens, plan: plan), pointerTips(of: scene, at: closes, plan: plan)).map { tips in
            tips.0.flatMap { from in tips.1.map { hypot($0.x - from.x, $0.y - from.y) } } ?? 0
        }
        return max(((travel + pointers).max() ?? 0) * plan.outputScale, seamTravel(into: plan.sceneIndex(at: time), at: sceneTime, across: shutter, plan: plan))
    }

    /// The frame at `time` as a shutter open for an instant sees it, with layers drawn sharp where they are at `sharp`, the
    /// frame's own time.
    private static func still(at time: Double, sharpAt sharp: Double, plan: MotionPlan, frames: [MotionPlan.LayerKey: CIImage]) -> CIImage {
        let bounds = CGRect(origin: .zero, size: plan.outputSize)
        let index = plan.sceneIndex(at: time)
        let sceneTime = time - plan.scenes[index].start
        let sharpTime = sharp - plan.scenes[index].start
        let background = CIImage(color: plan.background).cropped(to: bounds)
        var frame = sceneImage(index, at: sceneTime, sharpAt: sharpTime, plan: plan, frames: frames)
        // Under a transition, the scene before goes on from its end
        if let transition = plan.scenes[index].transition, index > 0, sceneTime < transition.duration {
            let previous = sceneImage(
                index - 1, at: plan.scenes[index - 1].duration + sceneTime, sharpAt: plan.scenes[index - 1].duration + sharpTime, plan: plan, frames: frames
            )
            frame = transitioned(previous, frame, into: index, at: sceneTime, plan: plan)
        }
        // An opening's control coming in over its ground alone, which is all there is before it
        if let arrival = plan.scenes[index].arrival, case let since = sceneTime - plan.scenes[index].arrivesAt, since < arrival.duration {
            let ground = ground(index, at: sceneTime, plan: plan).composited(over: background)
            frame = since < 0 ? ground : FieldRenderer.seam(
                arrival, between: (ground, frame.composited(over: background)), progress: arrival.progress(at: since), at: time, size: bounds.size
            )
        }
        return frame.composited(over: background).cropped(to: bounds)
    }

    /// Draws the frame at `time` into `buffer`, without color management: `context` must have none.
    static func draw(at time: Double, plan: MotionPlan, frames: [MotionPlan.LayerKey: CIImage] = [:], into buffer: CVPixelBuffer, context: CIContext) throws {
        let destination = CIRenderDestination(pixelBuffer: buffer)
        destination.colorSpace = nil
        _ = try context.startTask(toRender: image(at: time, plan: plan, frames: frames), to: destination).waitUntilCompleted()
    }

    /// A scene's layers at `time` in it, blurred as its camera is, over its field; layers drawn sharp where they are at
    /// `sharp`.
    private static func sceneImage(_ index: Int, at time: Double, sharpAt sharp: Double, plan: MotionPlan, frames: [MotionPlan.LayerKey: CIImage]) -> CIImage {
        let scene = plan.scenes[index]
        let field = ground(index, at: time, plan: plan)
        var image = CIImage.empty()
        var placements = plan.placements(of: scene, at: time, shown: sharp)
        if sharp != time, scene.layers.contains(where: \.isSharp) {
            placements = sharpened(placements, at: plan.placements(of: scene, at: sharp), of: scene)
        }
        for placement in placements {
            var layer = scene.layers[placement.layer]
            guard var content = content(of: &layer, at: time, take: frames[MotionPlan.LayerKey(scene: index, layer: placement.layer)]) else { continue }
            content = lettered(content, of: layer, at: time)
            if !layer.tints.isEmpty {
                content = shimmered(content, layer: layer, at: time, sceneDuration: scene.duration)
            }
            if let region = layer.region, case let dim = layer.value(.dim, at: time), dim > 0 {
                if let focusedImage = layer.focusedImage {
                    // Drawn once at the most it dims; part of the way there, faded over the layer
                    content = focusedImage.fading(to: min(dim / layer.mostDim, 1)).composited(over: content)
                } else {
                    content = MotionPlan.focused(content, on: region, dim: dim, height: layer.size.height)
                }
            }
            // Letters springing in are drawn in the room around the layer
            var room = placement
            room.corners = placement.roomCorners ?? placement.corners
            var layerImage = drawn(content, layer: layer, at: room, time: time, plan: plan)
            // On glass: over its panel, clipped to it, and the panel's shadow under both
            var shadow: CIImage?
            if let panel = GlassRenderer.panel(under: layer, at: placement, lit: SatinSetup.forShot(scene.fieldShot).glass, over: field, plan: plan) {
                let faded = { (image: CIImage) in placement.opacity < 1 ? image.fading(to: placement.opacity) : image }
                layerImage = layerImage.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: panel.body])
                    .composited(over: faded(panel.body))
                shadow = faded(panel.shadow)
            }
            // Over the glass too: a glass pane's own pixels are only its veil
            if layer.tints.contains(where: { $0.kind == .wash }) {
                layerImage = washed(layerImage, layer: layer, at: time) { over in washBounds(of: over, in: scene, placements: placements, plan: plan) }
            }
            image = (shadow.map { layerImage.composited(over: $0) } ?? layerImage).composited(over: image)
        }
        image = pointers(of: scene, at: time, plan: plan).composited(over: image)
        let bounds = CGRect(origin: .zero, size: plan.outputSize)
        let blur = scene.cameraValue(.blur, at: time) * plan.outputScale
        guard blur >= 0.3 else { return image.composited(over: field) }
        return image.clampedToExtent().applyingGaussianBlur(sigma: blur).cropped(to: bounds).composited(over: field)
    }

    /// The output pixels the layer `over` and its group's layers cover in `placements`.
    private static func washBounds(of over: Int, in scene: MotionPlan.Scene, placements: [MotionPlan.Placement], plan: MotionPlan) -> CGRect? {
        let points = placements.filter { scene.isLayer($0.layer, within: over) }.flatMap(\.corners)
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return nil }
        let scale = plan.outputScale
        return CGRect(x: minX * scale, y: (plan.canvas.height - maxY) * scale, width: (maxX - minX) * scale, height: (maxY - minY) * scale)
    }

    /// A layer's own pixels at `time`: its live take's frame (`take`), its field as typed, its shape as morphed (with its
    /// glow), or its image; `nil` when it has none.
    private static func content(of layer: inout MotionPlan.Layer, at time: Double, take: CIImage?) -> CIImage? {
        if let live = layer.live {
            return take.map { liveImage($0, live: live, at: time) }
        }
        if let typing = layer.typing {
            // Its glass as tall as the field is now, growing with its results
            layer.glass?.height = typing.height(at: time)
            return typed(typing, at: time, layer: layer)
        }
        if let morph = layer.morph {
            let shape = morph.image(at: time, scale: layer.rasterScale)
            // Its glow follows its shape: a recipe, blurred only where the frame needs it
            layer.shadowImage = layer.shadow.map { MotionPlan.silhouette(of: shape, shadow: $0, padding: layer.shadowPadding, scale: layer.rasterScale) }
            return shape
        }
        return layer.image
    }

    /// A scene's field at `time` in it, on the video's clock, so a field runs on across a cut to a scene with the
    /// same one. An opening whose control arrives in its look's seam swells in from black first.
    private static func ground(_ index: Int, at time: Double, plan: MotionPlan) -> CIImage {
        let scene = plan.scenes[index]
        var field = FieldRenderer.image(
            scene.field, palette: scene.palette, at: scene.start + time, size: plan.outputSize, preview: plan.isPreview,
            shot: shot(of: scene, at: time, plan: plan)
        )
        // The aurora's light goes out before the end, leaving the logo on black
        let strength = plan.fieldStrength * (scene.field == .aurora ? AuroraSetup.light(at: scene.start + time, length: plan.duration) : 1)
        if strength < 1 {
            field = field.fading(to: strength).composited(over: CIImage(color: plan.background)).cropped(to: field.extent)
        }
        guard scene.arrival != nil, time < groundSwell else { return field }
        return field.fading(to: MotionEasing.enter.progress(max(time, 0) / groundSwell, duration: groundSwell))
    }

    /// How long an opening's ground takes to swell in from black.
    static let groundSwell = 0.6

    /// `scene` as its field sees it at `time` in it: how its camera has moved since the scene began,
    /// so each shot opens on its field as set up, whatever the camera's zoom.
    private static func shot(of scene: MotionPlan.Scene, at time: Double, plan: MotionPlan) -> FieldRenderer.Shot {
        let opening = plan.camera(of: scene, at: 0)
        let camera = plan.camera(of: scene, at: time)
        let middle = CGPoint(x: plan.canvas.width / 2, y: plan.canvas.height / 2)
        // Where the point the camera opened on (in the frame's middle then) is now
        let landed = camera.project([opening.lookAt.x, opening.lookAt.y, 0])?.point ?? middle
        let zoom = camera.magnification / opening.magnification
        return FieldRenderer.Shot(
            index: scene.fieldShot, start: scene.start,
            shift: CGVector(dx: (landed.x - middle.x) * plan.outputScale, dy: (landed.y - middle.y) * plan.outputScale),
            zoom: zoom.isFinite && zoom > 0 ? zoom : 1, isLast: scene.start == plan.scenes.last?.start
        )
    }

    /// A field being typed into at `time`, as the layer's image: the element as its last settled results
    /// left it, its row as typed so far, and the caret, at its lifts' scale over its whole box in whole
    /// pixels (as every layer image is: `CIPerspectiveTransform` maps an extent out to them).
    private static func typed(_ typing: TypedField, at time: Double, layer: MotionPlan.Layer) -> CIImage {
        let box = CGRect(x: 0, y: 0, width: (layer.size.width * typing.scale).rounded(), height: (layer.size.height * typing.scale).rounded())
        let (across, down) = (box.width / layer.size.width, box.height / layer.size.height)
        // Canvas pixels from the top-left corner to image pixels from the bottom-left one
        let pixels = { (rect: CGRect) in
            CGRect(x: rect.minX * across, y: box.height - rect.maxY * down, width: rect.width * across, height: rect.height * down)
        }
        // Each lift's top on its place's top, in whole pixels
        let placed = { (image: CIImage, top: Double, left: Double) in
            image.transformed(by: CGAffineTransform(
                translationX: (left * across).rounded() - image.extent.minX, y: box.height - (top * down).rounded() - image.extent.maxY
            ))
        }
        let row = pixels(typing.row)
        // The results below the row, with the selection where the presses have moved it
        let selection = typing.selection(at: time)
        let state = selection > 0 ? typing.selected[selection - 1] : typing.states[typing.state(at: time)].image
        var image = placed(state, 0, 0).cropped(to: CGRect(x: 0, y: 0, width: box.width, height: row.minY.rounded()))
        image = placed(typing.rows[typing.length(at: time)], typing.row.minY, typing.row.minX).composited(over: image)
        let caret = typing.caret(at: time)
        if caret.opacity > 0 {
            let frame = pixels(caret.frame)
            // Pure white is kept for the one thing being typed: Raycast's caret is 250 of 255
            let level = 250.0 / 255
            let bar = CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
                "inputExtent": CIVector(cgRect: frame), "inputRadius": frame.width / 2, "inputColor": CIColor(red: level, green: level, blue: level)
            ])?.outputImage
            image = (caret.opacity < 1 ? bar?.fading(to: caret.opacity) : bar)?.composited(over: image) ?? image
        }
        // Over its whole box, which the layer's quad is mapped from
        return image.composited(over: CIImage(color: .clear).cropped(to: box)).cropped(to: box)
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
