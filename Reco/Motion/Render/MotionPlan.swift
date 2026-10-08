//
//  MotionPlan.swift
//  Reco
//

import CoreGraphics
import CoreImage
import ImageIO
import OSLog
import simd

/// Everything needed to draw any frame of a motion document, built once per edit off the main
/// actor: each layer's image drawn at the largest scale it's shown, its keyframes as tracks, and
/// the scenes' start times. Immutable, so frames draw in any order and in parallel.
nonisolated struct MotionPlan: Sendable {

    /// A layer ready to draw. Groups have no image; their children follow them with `parent` set.
    nonisolated struct Layer: Sendable {
        let parent: Int?
        let base: [MotionProperty: Double]
        let anchor: CGPoint

        /// Keyframes set by hand: a property with them ignores its moves.
        let tracks: [MotionProperty: PropertyTrack]

        /// What the layer's moves do to each property (``MoveEffect``).
        var moves: [MotionProperty: [PropertyTrack]] = [:]

        /// How a text layer is revealed, and where its characters and lines are.
        var reveal: TextReveal?
        var parts: [CGRect] = []

        /// What a focus keeps lit, in canvas pixels from the layer's top-left corner.
        var region: CGRect?

        /// The image as its focus leaves it, dimmed by ``mostDim`` and blurred outside the region,
        /// drawn once per plan: blurring a lifted page per frame took 9.4 ms p95 at 1080p (M5).
        var focusedImage: CIImage?

        var mostDim: Double {
            moves[.dim]?.flatMap { $0.keyframes.map(\.value) }.max() ?? 0
        }

        /// Whether it has pixels of its own: not a group.
        let isDrawn: Bool

        /// The content's size in canvas pixels.
        let size: CGSize

        let shadow: LayerShadow?

        /// The content at ``rasterScale`` pixels per canvas pixel, from Core Image's bottom-left
        /// origin; `nil` for a group, empty text or a live take, or until the plan has drawn it.
        var image: CIImage?

        /// The live take it shows instead of an image.
        var live: Live?
        var rasterScale = 1.0

        /// The glass panel its content sits on; `nil` for a layer not on glass.
        var glass: GlassRenderer.Shape?

        /// The field typed into that it shows instead of an image.
        var typing: TypedField?

        /// A rectangle's states as its morphs and floods change it, generated afresh each frame (spec 0014).
        var morph: ShapeMorph?

        /// A kinetic reveal's caret, and its newest letters' colour.
        var accent: RGBAColor?

        /// When a pointer clicks it.
        var clicks: [Click] = []

        /// Drawn where it is at the frame's own time under motion blur, as a burst's particles are (``BurstExpansion/isParticles(_:)``).
        var isSharp = false

        /// The shadow, blurred once at ``rasterScale`` in the layer's own space and projected with
        /// it: blurring it per frame cost most of a frame (a 40 px shadow at 1080p). It spans the
        /// layer and ``shadowPadding`` around it.
        var shadowImage: CIImage?

        /// How far the shadow's blur reaches past the layer, in canvas pixels: 3 σ.
        var shadowPadding: Double {
            (shadow?.radius ?? 0) * 3
        }

        func value(_ property: MotionProperty, at time: Double) -> Double {
            MotionPlan.value(property, base: base[property] ?? 0, track: tracks[property], moves: moves[property], at: time)
        }

        /// The content's size at `time`: a morphing shape's changes.
        func size(at time: Double) -> CGSize {
            morph?.state(at: time).size ?? size
        }
    }

    nonisolated struct Scene: Sendable {
        let start: Double
        let duration: Double

        /// What the layers are drawn over, and its colours.
        let field: MotionField
        let palette: FieldPalette

        /// The scene's place among the video's scenes over the same field, from 0: satin lights each
        /// shot afresh with the next of its setups.
        var fieldShot = 0

        /// Parents before their children, in document order.
        var layers: [Layer]

        let camera: [MotionProperty: PropertyTrack]
        let cameraBase: [MotionProperty: Double]

        /// What the camera's moves and the seams on either side do.
        var cameraMoves: [MotionProperty: [PropertyTrack]] = [:]

        /// How the scene comes in over the one before, drawn under it meanwhile.
        var transition: SeamExpansion.Transition?

        /// How an opening macro's control comes in over its ground alone, a breath in
        /// (``ShotLayout/macroBreath``): in a light or dither film, its look's seam.
        var arrival: SeamExpansion.Transition?

        /// How long it's drawn past its end, under the next scene's transition.
        var overlap = 0.0

        func cameraValue(_ property: MotionProperty, at time: Double) -> Double {
            MotionPlan.value(property, base: cameraBase[property] ?? 0, track: camera[property], moves: cameraMoves[property], at: time)
        }
    }

    /// A property's value: its keyframes if it has any, else its base changed by its moves.
    static func value(_ property: MotionProperty, base: Double, track: PropertyTrack?, moves: [PropertyTrack]?, at time: Double) -> Double {
        if let track {
            return track.value(at: time)
        }
        guard let moves else { return base }
        return property.isFactor ? moves.reduce(base) { $0 * $1.value(at: time) } : moves.reduce(base) { $0 + $1.value(at: time) }
    }

    /// A layer where it lands on the canvas at one moment.
    nonisolated struct Placement: Equatable, Sendable {
        let layer: Int

        /// Top-left, top-right, bottom-right and bottom-left, in canvas pixels from the top-left.
        var corners: [CGPoint]

        /// The centre's distance from the camera; drawn farthest first.
        let depth: Double

        let opacity: Double

        /// In canvas pixels, scaled as the layer is.
        let blur: Double

        /// How many canvas pixels a layer pixel covers at its widest edge.
        let scale: Double

        /// The corners of the shadow's image, like ``corners``; `nil` without a shadow.
        var shadowCorners: [CGPoint]?

        /// The corners of the room its letters spring through (``Layer/revealRoom``), like ``corners``; `nil` without it.
        var roomCorners: [CGPoint]?

        /// The camera's blur at each corner in canvas pixels, signed: negative in front of what's
        /// in focus. Empty without depth of field.
        var defocus: [Double] = []
    }

    let canvas: CGSize

    /// Output pixels per canvas pixel.
    let outputScale: Double

    let frameRate: Int
    let background: CIColor

    /// How strongly fields show over the background (``MotionCanvas/fieldStrength``).
    var fieldStrength = 1.0

    /// Drawn for the editor's preview, which the window shows smaller: detail it can't show may be
    /// traded for speed.
    var isPreview = false
    private(set) var scenes: [Scene]

    /// Assets to lift before this plan can draw them sharp, by id, with the scale (image pixels per
    /// CSS pixel) to lift at: never lifted, or shown larger than their sharpest lift.
    private(set) var liftsNeeded: [String: Int] = [:]

    /// Live assets to bake before this plan can draw them sharp, by id, with the scale (video
    /// pixels per CSS pixel) to bake at: 0 to measure an element first, then whatever it's shown at.
    private(set) var bakesNeeded: [String: Int] = [:]

    /// What the video's sound is made from (spec 0013).
    private(set) var sound = SoundCueSheet()

    /// The pointer clicks show, when a layer has one.
    var pointer: MotionPointer?

    var duration: Double {
        scenes.last.map { $0.start + $0.duration } ?? 0
    }

    /// The output frame in pixels, even each way for the encoders.
    var outputSize: CGSize {
        CGSize(width: (canvas.width * outputScale / 2).rounded() * 2, height: (canvas.height * outputScale / 2).rounded() * 2)
    }

    var frameCount: Int {
        max(Int((duration * Double(frameRate)).rounded()), 1)
    }

    /// The scene on screen at `time` and the time within it.
    func scene(at time: Double) -> (scene: Scene, time: Double) {
        let index = sceneIndex(at: time)
        return (scenes[index], time - scenes[index].start)
    }

    func sceneIndex(at time: Double) -> Int {
        max(scenes.partitioningIndex { $0.start > time } - 1, 0)
    }

    /// What `scene`'s camera sees at `time` in it.
    func camera(of scene: Scene, at time: Double) -> CameraProjection {
        CameraProjection(
            lookAt: CGPoint(x: scene.cameraValue(.positionX, at: time), y: scene.cameraValue(.positionY, at: time)), dolly: scene.cameraValue(.positionZ, at: time),
            canvas: canvas, zoom: max(scene.cameraValue(.scale, at: time), 0.01)
        )
    }

    /// Where every drawn layer of `scene` lands at `time` in it, farthest first; layers out of
    /// sight, transparent or behind the camera are left out.
    func placements(of scene: Scene, at time: Double) -> [Placement] {
        let camera = camera(of: scene, at: time)
        let aperture = scene.cameraValue(.aperture, at: time)
        let focus = scene.cameraValue(.focus, at: time) + camera.focalLength - camera.dolly
        var worlds: [simd_double4x4] = []
        var opacities: [Double] = []
        worlds.reserveCapacity(scene.layers.count)
        opacities.reserveCapacity(scene.layers.count)
        var placements: [Placement] = []
        for (index, layer) in scene.layers.enumerated() {
            let transform = Transform3D(
                position: [layer.value(.positionX, at: time), layer.value(.positionY, at: time), layer.value(.positionZ, at: time)],
                anchor: layer.anchor,
                scale: layer.value(.scale, at: time),
                rotation: [layer.value(.rotationX, at: time), layer.value(.rotationY, at: time), layer.value(.rotationZ, at: time)]
            )
            let world = layer.parent.map { worlds[$0] } ?? matrix_identity_double4x4
            // A morphing shape changes size about its anchor
            let size = layer.size(at: time)
            let matrix = world * transform.matrix(size: size)
            let opacity = (layer.parent.map { opacities[$0] } ?? 1) * min(max(layer.value(.opacity, at: time), 0), 1)
            worlds.append(matrix)
            opacities.append(opacity)

            guard layer.isDrawn, opacity > 0, size.width > 0, size.height > 0 else { continue }
            let local = [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: size.width, y: size.height), CGPoint(x: 0, y: size.height)]
            let projected = local.compactMap { point in camera.project((matrix * SIMD4(point.x, point.y, 0, 1)).xyz) }
            guard projected.count == 4,
                  let center = camera.project((matrix * SIMD4(size.width / 2, size.height / 2, 0, 1)).xyz) else { continue }
            let corners = projected.map(\.point)
            let scale = Self.scale(of: corners, size: size)
            var placement = Placement(
                layer: index, corners: corners, depth: center.depth, opacity: opacity, blur: max(layer.value(.blur, at: time), 0) * scale, scale: scale
            )
            if aperture > 0 {
                placement.defocus = projected.map { aperture * ($0.depth - focus) / 100 }
            }
            let around = { (room: CGSize) -> [CGPoint]? in
                let corners = [
                    CGPoint(x: -room.width, y: -room.height), CGPoint(x: size.width + room.width, y: -room.height),
                    CGPoint(x: size.width + room.width, y: size.height + room.height), CGPoint(x: -room.width, y: size.height + room.height)
                ].compactMap { point in camera.project((matrix * SIMD4(point.x, point.y, 0, 1)).xyz)?.point }
                return corners.count == 4 ? corners : nil
            }
            if layer.shadow != nil {
                placement.shadowCorners = around(CGSize(width: layer.shadowPadding, height: layer.shadowPadding))
            }
            if case let room = layer.revealRoom, room != .zero {
                placement.roomCorners = around(room)
            }
            placements.append(placement)
        }
        // Stable: layers at the same depth keep their order
        return placements.enumerated().sorted { ($0.element.depth, $1.offset) > ($1.element.depth, $0.offset) }.map(\.element)
    }

    /// The largest ratio of a projected edge to the layer's own.
    private static func scale(of corners: [CGPoint], size: CGSize) -> Double {
        let length = { (start: CGPoint, end: CGPoint) in hypot(end.x - start.x, end.y - start.y) }
        return max(
            length(corners[0], corners[1]) / size.width, length(corners[3], corners[2]) / size.width,
            length(corners[0], corners[3]) / size.height, length(corners[1], corners[2]) / size.height
        )
    }
}

// MARK: - Building

extension MotionPlan {

    /// Images are drawn as sharp as they're shown, up to this many times their canvas size times the
    /// output's scale, or more while their longer side stays within ``maximumImageSide``: sharp through
    /// a 4× push of a whole page without a texture past Metal's 16,384 px, and a small control in macro
    /// too (the approved film showed Supabase's search bar at 14× on 1080p, spec 0012).
    nonisolated static let maximumRasterScale = 4.0
    nonisolated static let maximumImageSide = 8192.0

    /// How often the largest shown scale is sampled while building.
    nonisolated static let rasterSampleRate = 30.0

    nonisolated private static let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "MotionPlan")

    /// Builds the plan off the main actor. Images are read from `bundle`.
    /// - Parameters:
    ///   - shorterSide: The output's shorter side in pixels, or `nil` for the canvas's own.
    ///   - frameRate: Frames per second, or `nil` for the canvas's.
    @concurrent
    static func build(_ document: MotionDocument, bundle: URL, shorterSide: CGFloat? = nil, frameRate: Int? = nil) async -> MotionPlan {
        let signpost = signposter.beginInterval("Build")
        defer { signposter.endInterval("Build", signpost) }

        let canvas = document.canvas.size
        var lifts: [String: UILiftCache.Lift] = [:]
        var takes: [String: UILiftCache.Take] = [:]
        var measured: [String: UILiftCache.TakeInfo] = [:]
        for asset in document.assets {
            if asset.steps == nil {
                lifts[asset.id] = UILiftCache.best(asset, in: bundle)
            } else {
                takes[asset.id] = UILiftCache.take(asset, in: bundle)
                measured[asset.id] = UILiftCache.info(asset, in: bundle)
            }
        }
        let sizes = UILiftCache.sizes(of: document, in: bundle)
        let outputScale = shorterSide.map { $0 / min(canvas.width, canvas.height) } ?? 1
        // Shots laid out, rolls and cascades split: what's drawn from here on
        let expanded = DocumentExpansion.expanded(document, sizes: sizes)
        var start = 0.0
        var scenes = expanded.scenes.map { scene in
            defer { start += scene.duration }
            let context = MoveContext(sceneDuration: scene.duration, canvas: canvas)
            // A closing is drawn on black, whatever the video's field: over a dithered sphere its small
            // caps didn't read
            let field = scene.shot?.kind == .closing ? .plain : scene.field ?? document.canvas.field
            var planned = Scene(
                start: start,
                duration: scene.duration,
                field: field,
                palette: FieldPalette(field, accent: document.style.accent, background: document.canvas.background),
                layers: flattened(scene.layers, parent: nil, sizes: sizes, context: context),
                camera: tracks(scene.camera.keyframes),
                cameraBase: Dictionary(uniqueKeysWithValues: MotionProperty.camera.map { ($0, scene.camera.base($0, canvas: canvas)) })
            )
            planned.cameraMoves = cameraMoves(scene.camera.moves, of: planned, context: context)
            return planned
        }
        addSeams(of: expanded, to: &scenes)
        var shots: [MotionField: Int] = [:]
        for index in scenes.indices {
            scenes[index].fieldShot = shots[scenes[index].field, default: 0]
            shots[scenes[index].field, default: 0] += 1
        }
        let color = document.canvas.background
        var plan = MotionPlan(
            canvas: canvas, outputScale: outputScale, frameRate: frameRate ?? document.canvas.frameRate,
            background: CIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha), fieldStrength: document.canvas.fieldStrength, scenes: scenes
        )
        plan.drawImages(for: expanded, bundle: bundle, lifts: lifts, takes: takes, measured: measured)
        plan.pointer = plan.hasClicks ? await MotionPointer.system() : nil
        plan.followSelections()
        return plan.scored(by: expanded)
    }

    /// A scene's camera follows the selection in its typed fields.
    nonisolated private mutating func followSelections() {
        for index in scenes.indices {
            scenes[index].cameraMoves[.positionY, default: []] += scenes[index].layers.flatMap { $0.typing?.follow() ?? [] }
        }
    }

    /// Draws every layer's image at the largest scale it's shown in its scene, and lists the lifts
    /// that are missing or too small for it.
    nonisolated private mutating func drawImages(
        for document: MotionDocument, bundle: URL, lifts: [String: UILiftCache.Lift], takes: [String: UILiftCache.Take],
        measured: [String: UILiftCache.TakeInfo]
    ) {
        let live = Set(document.assets.filter { $0.steps != nil }.map(\.id))
        let stills = Dictionary(document.assets.filter { $0.steps == nil }.map { ($0.id, $0) }) { first, _ in first }
        for (sceneIndex, scene) in document.scenes.enumerated() {
            let contents = Self.contents(of: scene.layers)
            var largest = [Double](repeating: 0, count: contents.count)
            let samples = Int((scene.duration * Self.rasterSampleRate).rounded(.up))
            for sample in 0...samples {
                for placement in placements(of: scenes[sceneIndex], at: min(Double(sample) / Self.rasterSampleRate, scene.duration)) {
                    largest[placement.layer] = max(largest[placement.layer], placement.scale)
                }
            }
            for index in contents.indices {
                let size = scenes[sceneIndex].layers[index].size
                let most = max(Self.maximumRasterScale, Self.maximumImageSide / max(size.width, size.height, 1) / outputScale)
                // A layer never seen is drawn at 1:1, in case an edit brings it in
                let shown = largest[index] > 0 ? min(largest[index], most) : 1
                let rasterScale = shown * outputScale
                scenes[sceneIndex].layers[index].rasterScale = rasterScale
                if case .lifted(let lifted) = contents[index], live.contains(lifted.asset) {
                    showLive(lifted.asset, on: MotionPlan.LayerKey(scene: sceneIndex, layer: index), rasterScale: rasterScale,
                             take: takes[lifted.asset], measured: measured[lifted.asset])
                    continue
                }
                if case .lifted(let lifted) = contents[index],
                   showStill(lifted, asset: stills[lifted.asset], on: MotionPlan.LayerKey(scene: sceneIndex, layer: index), lift: lifts[lifted.asset], bundle: bundle) {
                    continue
                }
                // A morphing shape is generated each frame, its glow with it
                guard scenes[sceneIndex].layers[index].morph == nil else { continue }
                let image = Self.image(of: contents[index], scale: rasterScale, size: scenes[sceneIndex].layers[index].size, bundle: bundle, lifts: lifts)
                scenes[sceneIndex].layers[index].image = image
                scenes[sceneIndex].layers[index].focusedImage = image.flatMap { Self.focusedImage(of: $0, layer: scenes[sceneIndex].layers[index]) }
                if let image, let shadow = scenes[sceneIndex].layers[index].shadow {
                    scenes[sceneIndex].layers[index].shadowImage = Self.shadow(
                        of: image, shadow: shadow, padding: scenes[sceneIndex].layers[index].shadowPadding, scale: rasterScale
                    )
                }
            }
        }
    }

    /// Asks for `lifted`'s still to be lifted when it's missing or softer than the layer `key` shows
    /// it, and puts its glass and typing on the layer; true when its typing draws it.
    nonisolated private mutating func showStill(_ lifted: UIContent, asset: MotionAsset?, on key: LayerKey, lift: UILiftCache.Lift?, bundle: URL) -> Bool {
        let layer = scenes[key.scene].layers[key.layer]
        let needed = Self.liftScale(for: lift, width: layer.size.width, rasterScale: layer.rasterScale)
        if needed > lift?.scale ?? 0 {
            liftsNeeded[lifted.asset] = max(liftsNeeded[lifted.asset] ?? 0, needed)
        }
        guard let asset, let lift else { return false }
        scenes[key.scene].layers[key.layer] = layer.dressed(showing: lifted, asset: asset, lift: lift, sceneDuration: scenes[key.scene].duration, bundle: bundle)
        guard scenes[key.scene].layers[key.layer].typing == nil else { return true }
        // Its typing isn't lifted yet, or not at this scale: all of it is lifted again
        if asset.typing != nil { liftsNeeded[lifted.asset] = max(liftsNeeded[lifted.asset] ?? 0, needed, lift.scale) }
        return false
    }

    /// Puts `asset`'s take on the layer, and asks for a bake when it hasn't been measured or is
    /// softer than the layer is shown.
    nonisolated private mutating func showLive(
        _ asset: String, on key: MotionPlan.LayerKey, rasterScale: Double, take: UILiftCache.Take?, measured: UILiftCache.TakeInfo?
    ) {
        let layer = scenes[key.scene].layers[key.layer]
        guard let measured else {
            bakesNeeded[asset] = bakesNeeded[asset] ?? 0
            return
        }
        let needed = Self.takeScale(for: measured, width: layer.size.width, rasterScale: rasterScale)
        if needed > (take?.info.scale ?? 0) {
            bakesNeeded[asset] = max(bakesNeeded[asset] ?? 0, needed)
        }
        guard let take else { return }
        let live = Live(take, asset: asset)
        scenes[key.scene].layers[key.layer].live = live
        guard let shadow = layer.shadow else { return }
        // Cast by the element's painted shape, or its box rounded as the element is
        let radius = take.info.radius * layer.size.width / take.info.crop.width
        let box = live.matte.map { matte in
            matte.transformed(by: CGAffineTransform(
                scaleX: layer.size.width * rasterScale / matte.extent.width, y: layer.size.height * rasterScale / matte.extent.height
            ))
        } ?? Self.roundedRectangle(size: layer.size, radius: radius, scale: rasterScale)
        scenes[key.scene].layers[key.layer].shadowImage = Self.shadow(of: box, shadow: shadow, padding: layer.shadowPadding, scale: rasterScale)
    }
}

// MARK: - Sound

extension MotionPlan {

    /// The plan with its sound's cue sheet, from `document` as it was laid out for the plan.
    nonisolated func scored(by document: MotionDocument) -> MotionPlan {
        var plan = self
        plan.sound = SoundCueSheet.make(plan: self, document: document)
        return plan
    }
}

private extension SIMD4<Double> {
    nonisolated var xyz: SIMD3<Double> {
        SIMD3(x, y, z)
    }
}
