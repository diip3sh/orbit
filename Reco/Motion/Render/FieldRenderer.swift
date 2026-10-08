//
//  FieldRenderer.swift
//  Reco
//

import CoreImage
import OSLog

/// Draws a scene's field (``MotionField``) at any moment, with the kernels in `FieldKernels.metal.txt`
/// coloured by ``FieldPalette``. A field is a pure function of its time and shot, so preview and export
/// match.
nonisolated enum FieldRenderer {

    /// Where a field is drawn: which of the video's scenes over it, when that scene began, and how its
    /// camera has moved since, as the planes at z 0 see it.
    nonisolated struct Shot: Equatable, Sendable {
        /// The scene's place among the video's scenes over the same field, from 0.
        var index = 0

        /// When the scene began, on the video's clock.
        var start = 0.0

        /// How far the canvas point in the frame's middle as the scene began has moved, in output
        /// pixels, y down.
        var shift = CGVector.zero

        /// How many times larger the planes show than as the scene began.
        var zoom = 1.0
    }

    /// How much of the camera's move a field follows, as ground far behind the planes would: pinned to
    /// the frame, it read as a wallpaper behind a whip (spec 0012, L1b). Satin's slab lies nearer, as
    /// the film had it.
    static let groundParallax = 0.15
    static let slabParallax = 0.35

    /// The looks were picked on a 1280×720 tile drawn at a pixel ratio of 2. A field is drawn as that
    /// tile would be, its shorter side this many reference pixels, so its grain and pattern keep
    /// their size against the frame at any output size.
    static let referenceShorterSide = 720.0

    /// A look's settings as picked (`docs/references/paper-shaders/README.md`).
    private struct Look {
        let kernel: String

        /// How fast the look's clock runs against the video's.
        let speed: Double

        /// The darkening at the frame's corners, as the gallery laid it over.
        let vignette: Double

        /// The kernel's look-specific values: the grain gradient's softness, intensity, noise and shape;
        /// dithering's shape, cell in reference pixels, scale and its dots' strength; the smoke ring's radius,
        /// thickness, inner shape and noise scale.
        let values: CIVector
    }

    /// How strong the dots of a dither that fills the frame are, against the sphere's.
    static let fillingDots = 0.55

    private static let grain = "grainGradientField"
    private static let dithering = "ditheringField"

    /// The picked looks, and their shaders' other shapes with the picked look's settings. Shapes are the
    /// kernels' kinds: grain 1 wave, 4 corners, 5 ripple, 6 blob, 7 sphere; dither 2 warp, 4 wave, 6 swirl,
    /// 7 sphere.
    private static let looks: [MotionField: Look] = [
        // Softness 0.6, intensity 0.35, noise 0.3, corners
        .ember: Look(kernel: grain, speed: 0.4, vignette: 0.2, values: CIVector(x: 0.6, y: 0.35, z: 0.3, w: 4)),
        // Softness 0.7, intensity 0.15, noise 0.5, wave
        .sunlit: Look(kernel: grain, speed: 0.35, vignette: 0.3, values: CIVector(x: 0.7, y: 0.15, z: 0.5, w: 1)),
        .bloom: Look(kernel: grain, speed: 0.4, vignette: 0.2, values: CIVector(x: 0.6, y: 0.35, z: 0.3, w: 6)),
        .orb: Look(kernel: grain, speed: 0.4, vignette: 0.2, values: CIVector(x: 0.6, y: 0.35, z: 0.3, w: 7)),
        .ripple: Look(kernel: grain, speed: 0.4, vignette: 0.2, values: CIVector(x: 0.6, y: 0.35, z: 0.3, w: 5)),
        // A sphere at scale 0.6 in 2 px cells at a pixel ratio of 2. The shapes that fill the frame light
        // half of it: at the sphere's strength, Supabase's docs text over swirl didn't read
        .matrix: Look(kernel: dithering, speed: 0.35, vignette: 0.5, values: CIVector(x: 7, y: 4, z: 0.6, w: 1)),
        .warp: Look(kernel: dithering, speed: 0.35, vignette: 0.5, values: CIVector(x: 2, y: 4, z: 0.6, w: fillingDots)),
        .swirl: Look(kernel: dithering, speed: 0.35, vignette: 0.5, values: CIVector(x: 6, y: 4, z: 0.6, w: fillingDots)),
        .tide: Look(kernel: dithering, speed: 0.35, vignette: 0.5, values: CIVector(x: 4, y: 4, z: 0.6, w: fillingDots)),
        // Radius 0.3, thickness 0.65, inner shape 0.7, noise scale 3
        .halo: Look(kernel: "smokeRingField", speed: 0.3, vignette: 0, values: CIVector(x: 0.3, y: 0.65, z: 0.7, w: 3))
    ]

    /// Reco's own, drawn in stages instead of as one look: satin, its grain, glass, the seams.
    private static let ownKernels = ["satinGround", "satinFinish", "filmGrainNoise", "filmGrain", "glassPanel", "glowSeam", "ditherSeam", "ringSeam"]

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "FieldRenderer")

    /// Compiled from `FieldKernels.metal.txt` the first time a field is drawn, by the system's Metal
    /// compiler: a `.metal` file in the target would need Xcode's separate Metal toolchain to build.
    /// Each alone: compiled together, only the first sampling kernel drawn worked.
    private static let kernels: [String: CIKernel] = {
        do {
            guard let url = Bundle.main.url(forResource: "FieldKernels.metal", withExtension: "txt") else { throw CocoaError(.fileNoSuchFile) }
            let source = try String(contentsOf: url, encoding: .utf8)
            var kernels: [String: CIKernel] = [:]
            for name in Set(looks.values.map(\.kernel)).union(ownKernels) {
                kernels[name] = try CIKernel.kernels(withMetalString: "#define \(name)_ONLY\n" + source).first
            }
            return kernels
        } catch {
            logger.error("Field kernels didn't compile, fields are drawn plain: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }()

    /// One of the kernels in `FieldKernels.metal.txt`, if it compiled.
    static func kernel(named name: String) -> CIKernel? {
        kernels[name]
    }

    /// The noise image the grain gradient and smoke ring sample, flipped so its first row is at the
    /// bottom as WebGL uploaded it, and clamped at its edges as WebGL sampled it.
    private static let noise: CIImage? = Bundle.main.url(forResource: "FieldNoise", withExtension: "png").flatMap { CIImage(contentsOf: $0) }.map {
        $0.transformed(by: CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -$0.extent.height)).clampedToExtent()
    }

    private static let noiseExtent = CGRect(x: 0, y: 0, width: 128, height: 128)

    /// `field` at `time` seconds into the video, over a frame of `size` output pixels.
    /// - Parameters:
    ///   - preview: Whether to draw the soft looks at most at their reference size, scaled up: ember
    ///     at 1080p took 4.1 ms p50 drawn whole, 1.5 ms at 720p (M5). An export draws them whole, for
    ///     crisp grain. Every field in a frame is scaled alike: two images of one kernel moved
    ///     differently in one frame drew one of them as streaks (macOS 26.5), so a camera's move is the
    ///     kernel's argument.
    ///   - shot: The scene it's drawn for. Paper's looks run on the video's clock, so one runs on across
    ///     a cut to a scene with the same one, and follow the camera at ``groundParallax``; dither
    ///     doesn't, so its cells stay on the frame's pixels. Satin is lit afresh for each shot.
    static func image(
        _ field: MotionField, palette: FieldPalette, at time: Double, size: CGSize, preview: Bool = false, shot: Shot = Shot()
    ) -> CIImage {
        let extent = CGRect(origin: .zero, size: size)
        let plain = CIImage(color: ciColor(palette.back)).cropped(to: extent)
        if field == .satin {
            return satin(SatinSetup.forShot(shot.index), palette: palette, at: time - shot.start, size: size, shot: shot) ?? plain
        }
        guard let look = looks[field], let kernel = kernels[look.kernel] else { return plain }
        // Reference pixels per output pixel, and drawn pixels per output pixel. Dither stays whole:
        // it's cheap, and its cells must stay sharp.
        let reference = referenceShorterSide / min(size.width, size.height)
        let dithered = look.kernel == dithering
        let drawScale = preview && !dithered ? min(1, reference) : 1
        let drawn = CGRect(x: 0, y: 0, width: (size.width * drawScale).rounded(.up), height: (size.height * drawScale).rounded(.up))
        let frame = CIVector(x: reference / drawScale, y: size.width * reference, z: size.height * reference, w: time * look.speed)
        // The camera's move as ground far behind the planes follows it, in reference pixels (y up)
        let view = CIVector(
            x: pow(shot.zoom, groundParallax), y: groundParallax * shot.shift.dx * reference, z: -groundParallax * shot.shift.dy * reference, w: 0
        )
        let colors = [vector(palette.back)] + palette.colors.map(vector)
        let arguments: [Any]
        if dithered {
            arguments = [frame, look.values, look.vignette] + colors
        } else {
            guard let noise else { return plain }
            arguments = [noise, frame, view, look.values, look.vignette] + colors
        }
        guard let image = kernel.apply(extent: drawn, roiCallback: { _, _ in noiseExtent }, arguments: arguments) else { return plain }
        guard drawScale < 1 else { return image }
        return image.clampedToExtent().transformed(by: CGAffineTransform(scaleX: 1 / drawScale, y: 1 / drawScale)).cropped(to: extent)
    }

    private static func vector(_ color: RGBAColor) -> CIVector {
        CIVector(x: color.red, y: color.green, z: color.blue, w: color.alpha)
    }

    private static func ciColor(_ color: RGBAColor) -> CIColor {
        CIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}

// MARK: - Seams

nonisolated extension FieldRenderer {

    /// A seam's front: the order's units it spans, and how bright its light goes (screened over the frame).
    static let glowWidth = 0.14
    static let glowLevel = 1.2

    /// Dither's cells in a seam, in reference pixels (12 px at 1080p: twice the field's, so the UI drawn in
    /// them still reads as dots at a video's bitrate), and how far the Bayer matrix spreads its front.
    static let ditherSeamCell = 8.0
    static let ditherSeamSpread = 0.3

    /// The ring's thickness in shorter sides, and its smoke's noise scale (the halo's).
    static let ringThickness = 0.25
    static let ringNoise = 3.0

    /// The scene before going into the next by a seam drawn in a field's language, at `progress`, `time`
    /// seconds into the video, over a frame of `size` output pixels. The next scene alone when the seam has
    /// no language or its kernel didn't compile.
    static func seam(
        _ transition: SeamExpansion.Transition, between scenes: (before: CIImage, next: CIImage), progress: Double, at time: Double, size: CGSize
    ) -> CIImage {
        let extent = CGRect(origin: .zero, size: size)
        let reference = referenceShorterSide / min(size.width, size.height)
        guard let palette = transition.palette, let look = looks[transition.look], let noise else { return scenes.next }
        let frame = { (speed: Double) in CIVector(x: reference, y: size.width * reference, z: size.height * reference, w: time * speed) }
        let lead = palette.colors.first.map(vector) ?? vector(palette.back)
        let deeper = palette.colors.dropFirst().first.map(vector) ?? lead
        let name: String
        let arguments: [Any]
        var reach = 0.0
        switch transition.seam {
        case .glow:
            name = "glowSeam"
            arguments = [noise, scenes.before, scenes.next, frame(look.speed), CIVector(x: progress, y: look.values.w, z: glowWidth, w: glowLevel), lead, deeper]
        case .dither:
            name = "ditherSeam"
            reach = ditherSeamCell / reference
            arguments = [
                scenes.before, scenes.next, frame(look.speed), CIVector(x: progress, y: look.values.x, z: ditherSeamCell, w: ditherSeamSpread),
                CIVector(x: look.values.z, y: time * look.speed, z: 0, w: 0), vector(palette.back), lead
            ]
        case .ring:
            name = "ringSeam"
            arguments = [noise, scenes.before, scenes.next, frame(look.speed), CIVector(x: progress, y: ringThickness, z: ringNoise, w: 0), lead, deeper]
        default:
            return scenes.next
        }
        let samplesNoise = transition.seam != .dither
        return kernels[name]?.apply(extent: extent, roiCallback: { index, rect in
            samplesNoise && index == 0 ? noiseExtent : rect.insetBy(dx: -reach, dy: -reach)
        }, arguments: arguments) ?? scenes.next
    }
}

// MARK: - Satin

nonisolated extension FieldRenderer {

    /// Satin's cloth is lit on a grid this many pixels on the frame's shorter side, or on the frame's
    /// own if that's smaller: it's out of focus, so a finer one changes nothing. The film's stills lit
    /// 270 and scaled up.
    static let satinGrid = 540.0

    /// The grain's deviation in levels of 255 in the mid-tones, as the film's frames had it (Raycast's
    /// measured about 2 at 1080p).
    static let grainAmount = 2.32

    /// `frame` (`size` output pixels) with satin's grain over it, its UI too, new for each frame
    /// `index`: clumps about a pixel wide at 1080p, on a grid of at most 1080 pixels on the shorter side
    /// scaled up past it, so it looks the same at any size.
    static func grained(_ frame: CIImage, index: Int, size: CGSize) -> CIImage {
        guard let noiseKernel = kernels["filmGrainNoise"], let grainKernel = kernels["filmGrain"] else { return frame }
        let step = max(min(size.width, size.height) / 1080, 1)
        let grid = CGRect(x: 0, y: 0, width: (size.width / step).rounded(.up), height: (size.height / step).rounded(.up)).insetBy(dx: -1, dy: -1)
        guard let noise = noiseKernel.apply(extent: grid, roiCallback: { _, rect in rect }, arguments: [Double(index)]) else { return frame }
        return grainKernel.apply(
            extent: CGRect(origin: .zero, size: size), roiCallback: { _, rect in rect.insetBy(dx: -2, dy: -2) },
            arguments: [frame, noise.transformed(by: CGAffineTransform(scaleX: step, y: step)), grainAmount]
        ) ?? frame
    }

    /// The cloth's black, taken off its light before it's encoded so the darkest valleys are 0.
    private static let satinBlack = 0.002

    /// `setup` at `time` seconds into its shot: the cloth lit in linear light, blurred out of focus and
    /// scaled to the frame, then exposed, encoded and covered by the slab.
    private static func satin(_ setup: SatinSetup, palette: FieldPalette, at time: Double, size: CGSize, shot: Shot) -> CIImage? {
        guard let groundKernel = kernels["satinGround"], let finishKernel = kernels["satinFinish"] else { return nil }
        let shorter = min(size.width, size.height)
        // Frame pixels per grid pixel, and the depth of field's blur in grid pixels
        let step = max(shorter / satinGrid, 1)
        let blur = setup.defocus * shorter / 1080 / step
        let margin = (3 * blur).rounded(.up) + 2
        let grid = CGRect(x: 0, y: 0, width: (size.width / step).rounded(.up), height: (size.height / step).rounded(.up))
            .insetBy(dx: -margin, dy: -margin)
        let folds = (0..<SatinSetup.mostFolds).flatMap { index -> [CIVector] in
            guard index < setup.folds.count else { return [CIVector(x: 0, y: 0, z: 0, w: 0), CIVector(x: 1, y: 1, z: 1, w: 0)] }
            let fold = setup.folds[index]
            return [
                CIVector(x: fold.center.x, y: fold.center.y, z: fold.angle * .pi / 180, w: fold.bend),
                CIVector(x: fold.length, y: fold.near, z: fold.far, w: fold.height)
            ]
        }
        let pools = (0..<SatinSetup.mostPools).map { index in
            guard index < setup.pools.count else { return CIVector(x: 0, y: 0, z: 1, w: 0) }
            let pool = setup.pools[index]
            return CIVector(x: pool.center.x, y: pool.center.y, z: pool.radius, w: pool.strength)
        }
        let ground: [Any] = [
            CIVector(x: step, y: size.width, z: size.height, w: time + setup.clock),
            satinView(of: shot, at: groundParallax),
            CIVector(x: setup.drift.dx, y: setup.drift.dy, z: setup.undulation, w: setup.breathing),
            CIVector(x: setup.light.x, y: setup.light.y, z: setup.light.z, w: setup.crest),
            setup.occlusion
        ] + folds + pools
        guard let lit = groundKernel.apply(extent: grid, roiCallback: { _, rect in rect }, arguments: ground) else { return nil }
        let blurred = lit.applyingGaussianBlur(sigma: blur).transformed(by: CGAffineTransform(scaleX: step, y: step))
        let slab = setup.slab
        let finish: [Any] = [
            blurred,
            CIVector(x: 1080 / shorter, y: size.width, z: size.height, w: 0),
            CIVector(x: setup.exposure, y: satinBlack, z: 0, w: 0),
            satinView(of: shot, at: slabParallax),
            CIVector(x: slab?.point.x ?? 0, y: slab?.point.y ?? 0, z: (slab?.angle ?? 0) * .pi / 180, w: slab?.bevel ?? 0),
            CIVector(x: slab?.level ?? 0, y: slab?.groove ?? 0, z: slab?.glint ?? 0, w: slab?.falloff ?? 1),
            CIVector(x: slab?.shadow ?? 0, y: slab?.shadowWidth ?? 1, z: slab?.tilt ?? 0, w: 0),
            vector(palette.back), vector(palette.colors.first ?? palette.back)
        ]
        let extent = CGRect(origin: .zero, size: size)
        guard let finished = finishKernel.apply(extent: extent, roiCallback: { _, rect in rect.insetBy(dx: -2, dy: -2) }, arguments: finish) else {
            return nil
        }
        guard let softness = slab.map({ $0.softness * shorter / 1080 }), softness >= 0.3 else { return finished }
        return finished.clampedToExtent().applyingGaussianBlur(sigma: softness).cropped(to: extent)
    }

    /// The camera's move at `share` of it as satin's kernels take it: the zoom, and the shift in output
    /// pixels, y down.
    private static func satinView(of shot: Shot, at share: Double) -> CIVector {
        CIVector(x: pow(shot.zoom, share), y: share * shot.shift.dx, z: share * shot.shift.dy, w: 0)
    }
}
