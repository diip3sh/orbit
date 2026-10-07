//
//  FieldRenderer.swift
//  Reco
//

import CoreImage
import OSLog

/// Draws a scene's field (``MotionField``) at any moment, with the kernels in `FieldKernels.metal.txt`
/// coloured by ``FieldPalette``. A field is a pure function of its time, so preview and export match.
nonisolated enum FieldRenderer {

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

        /// The kernel's look-specific values, after its noise and frame.
        let values: CIVector?
    }

    private static let looks: [MotionField: Look] = [
        // Softness 0.6, intensity 0.35, noise 0.3, corners
        .ember: Look(kernel: "grainGradientField", speed: 0.4, vignette: 0.2, values: CIVector(x: 0.6, y: 0.35, z: 0.3, w: 4)),
        .matrix: Look(kernel: "ditheringField", speed: 0.35, vignette: 0.5, values: nil),
        // Radius 0.3, thickness 0.65, inner shape 0.7, noise scale 3
        .halo: Look(kernel: "smokeRingField", speed: 0.3, vignette: 0, values: CIVector(x: 0.3, y: 0.65, z: 0.7, w: 3)),
        // Softness 0.7, intensity 0.15, noise 0.5, wave
        .sunlit: Look(kernel: "grainGradientField", speed: 0.35, vignette: 0.3, values: CIVector(x: 0.7, y: 0.15, z: 0.5, w: 1)),
        // Its folds move at the prototype's pace (docs/references/style-guide.md); its light pools itself
        .satin: Look(kernel: "satinField", speed: 1, vignette: 0, values: nil)
    ]

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "FieldRenderer")

    /// Compiled from `FieldKernels.metal.txt` the first time a field is drawn, by the system's Metal
    /// compiler: a `.metal` file in the target would need Xcode's separate Metal toolchain to build.
    /// Each alone: compiled together, only the first sampling kernel drawn worked.
    private static let kernels: [String: CIKernel] = {
        do {
            guard let url = Bundle.main.url(forResource: "FieldKernels.metal", withExtension: "txt") else { throw CocoaError(.fileNoSuchFile) }
            let source = try String(contentsOf: url, encoding: .utf8)
            var kernels: [String: CIKernel] = [:]
            for name in Set(looks.values.map(\.kernel)) {
                kernels[name] = try CIKernel.kernels(withMetalString: "#define \(name)_ONLY\n" + source).first
            }
            return kernels
        } catch {
            logger.error("Field kernels didn't compile, fields are drawn plain: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }()

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
    ///     crisp grain.
    ///   - view: Where the camera puts the field in the frame, in output pixels: the identity at rest.
    ///     The dither ignores it, so its cells stay on the frame's pixels.
    static func image(
        _ field: MotionField, palette: FieldPalette, at time: Double, size: CGSize, preview: Bool = false, view: CGAffineTransform = .identity
    ) -> CIImage {
        let extent = CGRect(origin: .zero, size: size)
        let plain = CIImage(color: ciColor(palette.back)).cropped(to: extent)
        guard let look = looks[field], let kernel = kernels[look.kernel] else { return plain }
        // Reference pixels per output pixel, and drawn pixels per output pixel. The dither stays
        // whole: it's cheap, and its cells must stay sharp.
        let reference = referenceShorterSide / min(size.width, size.height)
        let drawScale = preview && field != .matrix ? min(1, reference) : 1
        let view = field == .matrix ? .identity : view
        // The part of the field the frame shows, in drawn pixels
        let shown = extent.applying(view.inverted())
        let drawn = CGRect(x: shown.minX * drawScale, y: shown.minY * drawScale, width: shown.width * drawScale, height: shown.height * drawScale).integral
        let frame = CIVector(x: reference / drawScale, y: size.width * reference, z: size.height * reference, w: time * look.speed)
        let colors = [vector(palette.back)] + palette.colors.map(vector)
        let arguments: [Any]
        switch field {
        case .ember, .sunlit, .halo:
            guard let noise, let values = look.values else { return plain }
            arguments = [noise, frame, values, look.vignette] + colors
        case .matrix:
            arguments = [frame, look.vignette] + colors
        case .satin:
            arguments = [frame] + colors
        case .plain:
            return plain
        }
        guard let image = kernel.apply(extent: drawn, roiCallback: { _, _ in noiseExtent }, arguments: arguments) else { return plain }
        guard drawScale < 1 || view != .identity else { return image }
        return image.clampedToExtent().transformed(by: CGAffineTransform(scaleX: 1 / drawScale, y: 1 / drawScale).concatenating(view)).cropped(to: extent)
    }

    private static func vector(_ color: RGBAColor) -> CIVector {
        CIVector(x: color.red, y: color.green, z: color.blue, w: color.alpha)
    }

    private static func ciColor(_ color: RGBAColor) -> CIColor {
        CIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}
