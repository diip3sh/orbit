//
//  TransitionRenderer.swift
//  Reco
//

import CoreImage
import OSLog

/// The graphic transitions any look may use (``MotionSeam/graphic``, spec 0019), drawn in the brand's colours: the devices
/// After Effects launch films change scenes with. Each takes the whole frames of the scene before and the next and the seam's
/// linear progress, and eases itself: several move parts one after another, each on its own curve.
nonisolated enum TransitionRenderer {

    /// The scene before into the next, `moment.progress` (linear) of the way through `transition` and `moment.time` seconds into
    /// it. `origin` is where what was clicked last is (output pixels), if anything.
    static func draw(
        _ transition: SeamExpansion.Transition, between scenes: (before: CIImage, next: CIImage), at moment: (progress: Double, time: Double),
        origin: CGPoint?, size: CGSize
    ) -> CIImage {
        let seam = Seam(transition: transition, scenes: scenes, progress: moment.progress, time: moment.time, origin: origin, size: size)
        let image = [.split, .flip, .cube, .flash, .stretch].contains(transition.seam) ? spatial(seam) : masked(seam)
        return (image ?? scenes.next).cropped(to: CGRect(origin: .zero, size: size))
    }

    /// What a seam is drawn from: its scenes, where it is, and the brand's colours as kernel arguments.
    struct Seam {
        let transition: SeamExpansion.Transition
        let scenes: (before: CIImage, next: CIImage)
        let progress: Double
        let time: Double
        let origin: CGPoint?
        let size: CGSize

        /// The brand's two colours, then white and black.
        var colors: [CIVector] {
            (transition.colors + [RGBAColor(red: 1, green: 1, blue: 1, alpha: 1), RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)])
                .map { CIVector(x: $0.red, y: $0.green, z: $0.blue, w: 1) }
        }

        var unit: Double { size.height / 1080 }
        var middle: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }

        /// Which way it goes: two of a kind in a film go different ways.
        var turn: Double { transition.variant.isMultiple(of: 2) ? 1 : -1 }

        /// The frame's size, its pixels a pixel at 1080p, and `last`.
        func frame(_ last: Double) -> CIVector {
            CIVector(x: size.width, y: size.height, z: unit, w: last)
        }

        /// Both scenes clamped, so a kernel samples them anywhere.
        var sampled: [CIImage] { [scenes.before.clampedToExtent(), scenes.next.clampedToExtent()] }
    }

    /// The seams drawn by a kernel over the frame: masks, bands, blocks, blobs.
    private static func masked(_ seam: Seam) -> CIImage? {
        let (progress, size, colors) = (seam.progress, seam.size, seam.colors)
        switch seam.transition.seam {
        case .iris:
            let centre = seam.origin ?? seam.middle
            let reach = farthest(from: centre, size: size) * 1.02
            let (opened, followed) = (ease(progress / irisLead), ease((progress - (1 - irisLead)) / irisLead))
            return apply("irisSeam", seam.sampled + [
                seam.frame(0), CIVector(x: centre.x, y: centre.y, z: reach * opened, w: reach * followed),
                CIVector(x: 1 + irisPush * opened, y: irisFrom - (irisFrom - 1) * followed), colors[0]
            ], size: size)
        case .bars:
            let way = directions[seam.transition.variant % directions.count]
            let span = abs(way.dx) * size.width + abs(way.dy) * size.height
            let fronts = (0..<3).map { ease((progress - Double($0) * barStagger) / (1 - 2 * barStagger)) }
            let front = { (eased: Double) in -0.01 + (1 + barSlant + 0.02) * eased }
            return apply("barsSeam", seam.sampled + [
                CIVector(x: size.width, y: size.height, z: seam.unit, w: barSlant), CIVector(x: way.dx, y: way.dy, z: -way.dy, w: way.dx),
                CIVector(x: front(fronts[0]), y: front(fronts[1]), z: front(fronts[2]), w: (1 - fronts[2]) * barSlide * span), colors[0], colors[1]
            ], size: size)
        case .slats:
            return apply("slatsSeam", seam.sampled + [seam.frame(progress), CIVector(x: slatCount, y: slatWave, z: slatDim, w: 0)], size: size)
        case .tiles:
            let centre = seam.origin ?? [seam.middle, CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: size.height)][seam.transition.variant % 3]
            return apply("tilesSeam", seam.sampled + [
                seam.frame(progress), CIVector(x: tileSide * seam.unit, y: tileWave, z: centre.x, w: centre.y), colors[0]
            ], size: size)
        case .glitch:
            let strength = pow(sin(.pi * progress), 0.7)
            let shown = smooth(progress, from: 0.25, to: 0.75)
            return apply("glitchSeam", seam.sampled + [
                seam.frame(progress), CIVector(x: (seam.time * glitchRate).rounded(.down), y: strength, z: shown, w: 0), colors[0]
            ], size: size)
        case .pixelate:
            let steps = (seam.transition.duration * pixelRate).rounded()
            let stepped = min((progress * steps).rounded(.down) / steps, 1)
            let cell = max((pixelMost * size.height * pow(1 - abs(2 * stepped - 1), 1.5)).rounded(), 1)
            return apply("pixelSeam", seam.sampled + [seam.frame(0), CIVector(x: cell, y: stepped < 0.5 ? 0 : 1)], size: size)
        case .liquid:
            let centre = seam.origin ?? corner(seam.transition.variant, size: size)
            let reach = farthest(from: centre, size: size) * (1 + liquidWobble) * 1.05
            let radii = (0..<3).map { reach * ease((progress - Double($0) * liquidStagger) / (1 - 2 * liquidStagger)) }
            return apply("liquidSeam", seam.sampled + [
                seam.frame(seam.time), CIVector(x: centre.x, y: centre.y), CIVector(x: radii[0], y: radii[1], z: radii[2], w: liquidWobble),
                colors[0], colors[1]
            ], size: size)
        case .spin:
            return spun(seam)
        default:
            return nil
        }
    }

    /// The seams that move whole frames in space.
    private static func spatial(_ seam: Seam) -> CIImage? {
        let (scenes, progress, size) = (seam.scenes, seam.progress, seam.size)
        // A card or cube turns over the brand's second colour
        let second = seam.colors[1]
        let tint = CIColor(red: second.x, green: second.y, blue: second.z)
        switch seam.transition.seam {
        case .split:
            let shade = seam.transition.isLight ? MotionFrameRenderer.recedeShadeLight : splitShade
            return split(scenes, progress: progress, vertical: seam.turn > 0, edge: (seam.colors[0], shade), size: size)
        case .flip: return flipped(scenes, progress: progress, turn: seam.turn, ground: tint, size: size)
        case .cube: return cubed(scenes, progress: progress, turn: seam.turn, ground: tint, size: size)
        case .flash: return flashed(scenes, progress: progress, color: seam.colors[0], size: size)
        case .stretch: return stretched(scenes, progress: progress, horizontal: seam.turn > 0, size: size)
        default: return nil
        }
    }

    // MARK: - Kernels

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "TransitionRenderer")

    private static let kernelNames = ["irisSeam", "barsSeam", "slatsSeam", "tilesSeam", "glitchSeam", "pixelSeam", "liquidSeam", "spinSeam"]

    /// Compiled from `TransitionKernels.metal.txt` the first time one is drawn, each alone, as the fields are.
    private static let kernels: [String: CIKernel] = {
        do {
            guard let url = Bundle.main.url(forResource: "TransitionKernels.metal", withExtension: "txt") else { throw CocoaError(.fileNoSuchFile) }
            let source = try String(contentsOf: url, encoding: .utf8)
            var kernels: [String: CIKernel] = [:]
            for name in kernelNames {
                kernels[name] = try CIKernel.kernels(withMetalString: "#define \(name)_ONLY\n" + source).first
            }
            return kernels
        } catch {
            logger.error("Transition kernels didn't compile, graphic seams cut: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }()

    /// A kernel over the frame, sampling its scenes anywhere: they're clamped, so any region of them is there.
    private static func apply(_ name: String, _ arguments: [Any], size: CGSize) -> CIImage? {
        kernels[name]?.apply(extent: CGRect(origin: .zero, size: size), roiCallback: { _, rect in rect.insetBy(dx: -size.width, dy: -size.height) }, arguments: arguments)
    }

    /// The spin's two halves: the scene before turning away faster and faster, magnified and blurred along its turn, then the next
    /// turning in from the other side and settling.
    private static func spun(_ seam: Seam) -> CIImage? {
        let leaving = seam.progress < 0.5
        let half = leaving ? seam.progress / 0.5 : (seam.progress - 0.5) / 0.5
        // Cubic in, then cubic out: the turn's speed meets at the cut
        let (left, speed) = leaving ? (pow(half, 3), 3 * half * half) : (pow(1 - half, 3), 3 * pow(1 - half, 2))
        let angle = seam.turn * spinTurn * .pi / 180 * (leaving ? left : -left)
        let blur = spinTurn * .pi / 180 * speed / (seam.transition.duration / 2) * spinShutter
        return apply("spinSeam", [
            seam.sampled[leaving ? 0 : 1], seam.frame(0), CIVector(x: angle, y: 1 + spinZoom * left, z: blur, w: 0)
        ], size: seam.size)
    }

    // MARK: - Shared

    /// In-out quart, the graphic seams' curve: still at both ends, fastest in the middle (cubic-bezier(0.76, 0, 0.24, 1)).
    static func ease(_ linear: Double) -> Double {
        graphicEasing.progress(min(max(linear, 0), 1), duration: 1)
    }

    static let graphicEasing = MotionEasing.cubicBezier(0.76, 0, 0.24, 1)

    private static func smooth(_ value: Double, from start: Double, to end: Double) -> Double {
        let share = min(max((value - start) / (end - start), 0), 1)
        return share * share * (3 - 2 * share)
    }

    /// How far the frame's farthest corner is from `point`.
    static func farthest(from point: CGPoint, size: CGSize) -> Double {
        [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
            .map { hypot($0.x - point.x, $0.y - point.y) }.max() ?? 0
    }

    /// The corner a liquid swells out of without a click: bottom left, top right, bottom right, top left, in turn.
    private static func corner(_ variant: Int, size: CGSize) -> CGPoint {
        [CGPoint.zero, CGPoint(x: size.width, y: size.height), CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height)][variant % 4]
    }

    /// The ways bars sweep, in turn: rightwards, up, leftwards, down.
    private static let directions = [CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: 1), CGVector(dx: -1, dy: 0), CGVector(dx: 0, dy: -1)]

    // MARK: - Measures

    /// An iris's colour leads over 0.85 of it and the next scene's disc follows 0.15 behind, so its ring is widest half way and
    /// gone at both ends; the scene before is pushed 8 % closer, the next comes back from 1.15×.
    static let irisLead = 0.85
    static let irisPush = 0.08
    static let irisFrom = 1.15

    /// Bars follow each other 0.13 of the seam apart, their edges leaning 0.18 of the span; the next scene slides a quarter of the
    /// span behind its bar.
    static let barStagger = 0.13
    static let barSlant = 0.18
    static let barSlide = 0.25

    /// Seven slats, the outermost starting 0.35 of the seam after the middle ones; what's under them darkens by 0.4.
    static let slatCount = 7.0
    static let slatWave = 0.35
    static let slatDim = 0.4

    /// Tiles 120 px a side at 1080p (nine rows), the farthest opening 0.55 of the seam after the nearest.
    static let tileSide = 120.0
    static let tileWave = 0.55

    /// A glitch tears anew 24 times a second; pixels step 15 times a second, their blocks up to 9 % of the frame's height.
    static let glitchRate = 24.0
    static let pixelRate = 15.0
    static let pixelMost = 0.09

    /// Liquid's three blobs follow each other 0.12 of the seam apart, their edges wobbling 12 % of their radius.
    static let liquidStagger = 0.12
    static let liquidWobble = 0.12

    /// A spin turns each frame 50° and magnifies it 1.3× at the cut, blurred over the turn a 0.04 s shutter sees.
    static let spinTurn = 50.0
    static let spinZoom = 0.3
    static let spinShutter = 0.04
}
