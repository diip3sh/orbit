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
        let tracks: [MotionProperty: PropertyTrack]

        /// Whether it has pixels of its own: not a group.
        let isDrawn: Bool

        /// The content's size in canvas pixels.
        let size: CGSize

        let shadow: LayerShadow?

        /// The content at ``rasterScale`` pixels per canvas pixel, from Core Image's bottom-left
        /// origin; `nil` for a group or empty text, or until the plan has drawn it.
        var image: CIImage?
        var rasterScale = 1.0

        /// The shadow, blurred once at ``rasterScale`` in the layer's own space and projected with
        /// it: blurring it per frame cost most of a frame (a 40 px shadow at 1080p). It spans the
        /// layer and ``shadowPadding`` around it.
        var shadowImage: CIImage?

        /// How far the shadow's blur reaches past the layer, in canvas pixels: 3 σ.
        var shadowPadding: Double {
            (shadow?.radius ?? 0) * 3
        }

        func value(_ property: MotionProperty, at time: Double) -> Double {
            tracks[property]?.value(at: time) ?? base[property] ?? 0
        }
    }

    nonisolated struct Scene: Sendable {
        let start: Double
        let duration: Double

        /// Parents before their children, in document order.
        var layers: [Layer]

        let camera: [MotionProperty: PropertyTrack]
        let cameraBase: [MotionProperty: Double]
    }

    /// A layer where it lands on the canvas at one moment.
    nonisolated struct Placement: Equatable, Sendable {
        let layer: Int

        /// Top-left, top-right, bottom-right and bottom-left, in canvas pixels from the top-left.
        let corners: [CGPoint]

        /// The centre's distance from the camera; drawn farthest first.
        let depth: Double

        let opacity: Double

        /// In canvas pixels, scaled as the layer is.
        let blur: Double

        /// How many canvas pixels a layer pixel covers at its widest edge.
        let scale: Double

        /// The corners of the shadow's image, like ``corners``; `nil` without a shadow.
        var shadowCorners: [CGPoint]?
    }

    let canvas: CGSize

    /// Output pixels per canvas pixel.
    let outputScale: Double

    let frameRate: Int
    let background: CIColor
    private(set) var scenes: [Scene]

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
        let index = max(scenes.partitioningIndex { $0.start > time } - 1, 0)
        return (scenes[index], time - scenes[index].start)
    }

    /// Where every drawn layer of `scene` lands at `time` in it, farthest first; layers out of
    /// sight, transparent or behind the camera are left out.
    func placements(of scene: Scene, at time: Double) -> [Placement] {
        let camera = CameraProjection(
            lookAt: CGPoint(x: cameraValue(.positionX, scene, time), y: cameraValue(.positionY, scene, time)), dolly: cameraValue(.positionZ, scene, time),
            canvas: canvas
        )
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
            let matrix = world * transform.matrix(size: layer.size)
            let opacity = (layer.parent.map { opacities[$0] } ?? 1) * min(max(layer.value(.opacity, at: time), 0), 1)
            worlds.append(matrix)
            opacities.append(opacity)

            guard layer.isDrawn, opacity > 0 else { continue }
            let local = [CGPoint.zero, CGPoint(x: layer.size.width, y: 0), CGPoint(x: layer.size.width, y: layer.size.height), CGPoint(x: 0, y: layer.size.height)]
            let projected = local.compactMap { point in camera.project((matrix * SIMD4(point.x, point.y, 0, 1)).xyz) }
            guard projected.count == 4,
                  let center = camera.project((matrix * SIMD4(layer.size.width / 2, layer.size.height / 2, 0, 1)).xyz) else { continue }
            let corners = projected.map(\.point)
            let scale = Self.scale(of: corners, size: layer.size)
            var placement = Placement(
                layer: index, corners: corners, depth: center.depth, opacity: opacity, blur: max(layer.value(.blur, at: time), 0) * scale, scale: scale
            )
            if layer.shadow != nil {
                let padding = layer.shadowPadding
                let padded = [
                    CGPoint(x: -padding, y: -padding), CGPoint(x: layer.size.width + padding, y: -padding),
                    CGPoint(x: layer.size.width + padding, y: layer.size.height + padding), CGPoint(x: -padding, y: layer.size.height + padding)
                ].compactMap { point in camera.project((matrix * SIMD4(point.x, point.y, 0, 1)).xyz)?.point }
                placement.shadowCorners = padded.count == 4 ? padded : nil
            }
            placements.append(placement)
        }
        // Stable: layers at the same depth keep their order
        return placements.enumerated().sorted { ($0.element.depth, $1.offset) > ($1.element.depth, $0.offset) }.map(\.element)
    }

    private func cameraValue(_ property: MotionProperty, _ scene: Scene, _ time: Double) -> Double {
        scene.camera[property]?.value(at: time) ?? scene.cameraBase[property] ?? 0
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

    /// Images are drawn at most this many times their canvas size times the output's scale: sharp
    /// through a 4× push without a texture past Metal's 16,384 px.
    nonisolated static let maximumRasterScale = 4.0

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
        let outputScale = shorterSide.map { $0 / min(canvas.width, canvas.height) } ?? 1
        var start = 0.0
        let scenes = document.scenes.map { scene in
            defer { start += scene.duration }
            return Scene(
                start: start,
                duration: scene.duration,
                layers: flattened(scene.layers, parent: nil),
                camera: tracks(scene.camera.keyframes),
                cameraBase: Dictionary(uniqueKeysWithValues: MotionProperty.camera.map { ($0, scene.camera.base($0, canvas: canvas)) })
            )
        }
        let color = document.canvas.background
        var plan = MotionPlan(
            canvas: canvas, outputScale: outputScale, frameRate: frameRate ?? document.canvas.frameRate,
            background: CIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha), scenes: scenes
        )
        plan.drawImages(for: document, bundle: bundle)
        return plan
    }

    /// Each scene's layers, parents first, with their sizes; images come later.
    nonisolated private static func flattened(_ layers: [MotionLayer], parent: Int?, into list: [Layer] = []) -> [Layer] {
        var list = list
        for layer in layers {
            var isGroup = false
            if case .group = layer.content {
                isGroup = true
            }
            list.append(Layer(
                parent: parent, base: Dictionary(uniqueKeysWithValues: MotionProperty.allCases.map { ($0, layer.base($0)) }),
                anchor: layer.transform.anchor, tracks: tracks(layer.keyframes), isDrawn: !isGroup, size: size(of: layer.content), shadow: layer.shadow
            ))
            if case .group(let children) = layer.content {
                list = flattened(children, parent: list.count - 1, into: list)
            }
        }
        return list
    }

    nonisolated private static func tracks(_ keyframes: [MotionProperty: [Keyframe]]) -> [MotionProperty: PropertyTrack] {
        keyframes.reduce(into: [:]) { tracks, entry in
            tracks[entry.key] = PropertyTrack(entry.key, keyframes: entry.value)
        }
    }

    nonisolated private static func size(of content: LayerContent) -> CGSize {
        switch content {
        case .text(let text): TextImage(text, scale: 0).size
        case .image(let image): image.size
        case .shape(let shape): shape.size
        case .group: .zero
        }
    }

    /// Draws every layer's image at the largest scale it's shown in its scene.
    nonisolated private mutating func drawImages(for document: MotionDocument, bundle: URL) {
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
                // A layer never seen is drawn at 1:1, in case an edit brings it in
                let shown = largest[index] > 0 ? min(largest[index], Self.maximumRasterScale) : 1
                let rasterScale = shown * outputScale
                scenes[sceneIndex].layers[index].rasterScale = rasterScale
                let image = Self.image(of: contents[index], scale: rasterScale, bundle: bundle)
                scenes[sceneIndex].layers[index].image = image
                if let image, let shadow = scenes[sceneIndex].layers[index].shadow {
                    scenes[sceneIndex].layers[index].shadowImage = Self.shadow(
                        of: image, shadow: shadow, padding: scenes[sceneIndex].layers[index].shadowPadding, scale: rasterScale
                    )
                }
            }
        }
    }

    /// Draws shadows once; without color management, as frames are.
    nonisolated private static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])

    /// The image's silhouette in black at the shadow's opacity, blurred, with `padding` canvas pixels
    /// around it, drawn into a bitmap.
    nonisolated private static func shadow(of image: CIImage, shadow: LayerShadow, padding: Double, scale: Double) -> CIImage? {
        let inset = padding * scale
        let silhouette = image
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: min(max(shadow.opacity, 0), 1))
            ])
            .transformed(by: CGAffineTransform(translationX: inset, y: inset))
            .applyingGaussianBlur(sigma: shadow.radius * scale)
        let bounds = CGRect(x: 0, y: 0, width: image.extent.width + 2 * inset, height: image.extent.height + 2 * inset).integral
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let bitmap = context.createCGImage(silhouette, from: bounds, format: .RGBA8, colorSpace: space) else { return nil }
        return CIImage(cgImage: bitmap)
    }

    nonisolated private static func contents(of layers: [MotionLayer]) -> [LayerContent] {
        layers.flatMap { layer -> [LayerContent] in
            if case .group(let children) = layer.content {
                return [layer.content] + contents(of: children)
            }
            return [layer.content]
        }
    }

    nonisolated private static func image(of content: LayerContent, scale: Double, bundle: URL) -> CIImage? {
        switch content {
        case .text(let text):
            return TextImage(text, scale: scale).image.map { CIImage(cgImage: $0) }
        case .shape(let shape):
            let color = shape.color
            return CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
                "inputExtent": CIVector(cgRect: CGRect(x: 0, y: 0, width: shape.size.width * scale, height: shape.size.height * scale)),
                "inputRadius": shape.cornerRadius * scale,
                "inputColor": CIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            ])?.outputImage
        case .image(let image):
            let pixels = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            guard let source = CGImageSourceCreateWithURL(bundle.appending(path: image.path) as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: max(pixels.width, pixels.height).rounded(.up)
                  ] as CFDictionary) else { return nil }
            // Stretched to the layer's size, as an <img> with both dimensions set
            return CIImage(cgImage: cgImage).transformed(by: CGAffineTransform(
                scaleX: pixels.width / CGFloat(cgImage.width), y: pixels.height / CGFloat(cgImage.height)
            ))
        case .group:
            return nil
        }
    }
}

private extension SIMD4<Double> {
    nonisolated var xyz: SIMD3<Double> {
        SIMD3(x, y, z)
    }
}
