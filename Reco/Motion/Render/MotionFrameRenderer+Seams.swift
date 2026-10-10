//
//  MotionFrameRenderer+Seams.swift
//  Reco
//

import CoreImage

/// Seams that move whole frames as things: the next scene rising on a card over the one before (``MotionSeam/stack``),
/// opening out of what it clicked (``MotionSeam/expand``), the camera diving through that into it (``MotionSeam/dive``), or
/// the frame melting into it (``MotionSeam/melt``).
nonisolated extension MotionFrameRenderer {

    /// Scene `index`'s frame `next` at `time` into its transition from the scene before's frame `before`, drawn as its seam
    /// draws them; a seam drawn by the camera alone (a whip) cross-fades its overlap.
    static func transitioned(_ before: CIImage, _ next: CIImage, into index: Int, at time: Double, plan: MotionPlan) -> CIImage {
        guard let transition = plan.scenes[index].transition else { return next }
        let bounds = CGRect(origin: .zero, size: plan.outputSize)
        let background = CIImage(color: plan.background).cropped(to: bounds)
        let (previous, frame) = (before.composited(over: background), next.composited(over: background))
        let progress = transition.progress(at: time)
        switch transition.seam {
        case .push:
            return next.transformed(by: CGAffineTransform(translationX: bounds.width * (1 - progress), y: 0))
                .composited(over: before.transformed(by: CGAffineTransform(translationX: -bounds.width * progress, y: 0)))
        case .stack:
            return stacked(previous, under: frame, progress: progress, isLight: plan.isLight)
        case .expand:
            return expanded(previous, into: frame, from: expandSource(into: index, at: time, plan: plan), progress: progress, isLight: plan.isLight)
        case .dive:
            return dived(previous, into: frame, from: expandSource(into: index, at: time, plan: plan), progress: progress, size: bounds.size)
        case .melt:
            return melted(previous, into: frame, progress: progress, palette: transition.palette, size: bounds.size)
        case .glow, .dither, .ring:
            return FieldRenderer.seam(transition, between: (previous, frame), progress: progress, at: plan.scenes[index].start + time, size: bounds.size)
        default:
            return before.fading(to: 1 - progress).composited(over: next)
        }
    }

    /// The next scene `progress` of the way up from below on a card, the scene before sinking back under it.
    static func stacked(_ before: CIImage, under next: CIImage, progress: Double, isLight: Bool = false) -> CIImage {
        let size = before.extent.size
        let card = CGRect(origin: CGPoint(x: 0, y: -size.height * (1 - progress)), size: size)
        let back = receded(before, about: CGPoint(x: size.width / 2, y: size.height / 2), growth: -stackSink, progress: progress, isLight: isLight)
        let shown = next.transformed(by: CGAffineTransform(translationX: 0, y: card.minY))
        return framed(shown, in: card, radius: stackRadius * size.height * (1 - progress), size: size).composited(over: back)
    }

    /// The next scene `progress` of the way out of `source` (output pixels) to the whole frame, the scene before diving
    /// towards it.
    static func expanded(_ before: CIImage, into next: CIImage, from source: CGRect, progress: Double, isLight: Bool = false) -> CIImage {
        let size = before.extent.size
        let mix = { (start: Double, end: Double) in start + (end - start) * progress }
        let rect = CGRect(x: mix(source.minX, 0), y: mix(source.minY, 0), width: mix(source.width, size.width), height: mix(source.height, size.height))
        // The next scene fills the rectangle, as an app's first screen grows out of its icon
        let fill = max(rect.width / size.width, rect.height / size.height)
        let shown = next.transformed(by: CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
            .concatenating(CGAffineTransform(scaleX: fill, y: fill))
            .concatenating(CGAffineTransform(translationX: rect.midX, y: rect.midY)))
        let back = receded(before, about: CGPoint(x: source.midX, y: source.midY), growth: expandDive, progress: progress, isLight: isLight)
        let radius = min(source.width, source.height) * expandRadius * (1 - progress)
        return framed(shown, in: rect, radius: radius, size: size).composited(over: back)
    }

    /// The camera `progress` of the way through `source` (output pixels) into the next scene: the scene before magnified about
    /// it, log-even, until it covers the frame, tilting about it as it comes and squaring its corners off; the next scene seen
    /// through it, coming up from further back and out of a blur; a glass rim round it until it's past.
    static func dived(_ before: CIImage, into next: CIImage, from source: CGRect, progress: Double, size: CGSize) -> CIImage {
        let frame = CGRect(origin: .zero, size: size)
        let unit = size.height / 1080
        let zoom = pow(diveReach(of: source, size: size), progress)
        let centre = CGPoint(x: source.midX + (frame.midX - source.midX) * progress, y: source.midY + (frame.midY - source.midY) * progress)
        let toward = about(CGPoint(x: source.midX, y: source.midY), scale: zoom, onto: centre)
        let window = source.applying(toward)
        let squared = 1 - MotionEasing.enter.progress(min(max((progress - 0.6) / 0.4, 0), 1), duration: 1)
        let radius = min(source.width, source.height) / 2 * zoom * squared
        // The side the source is on comes nearer, as Vantae's pill's send did
        let angle = diveTilt * sin(.pi * progress) * (source.midX >= frame.midX ? 1 : -1)
        let tilt = { (image: CIImage) in tilted(image, about: centre, angle: angle, size: size) }
        let margin = frame.insetBy(dx: -size.width * 0.25, dy: -size.height * 0.25)
        let plane = tilt(before.clampedToExtent().transformed(by: toward).cropped(to: margin))
        let corner = min(radius, min(window.width, window.height) / 2)
        let shape = { (color: CIColor, filter: String, extra: [String: Any]) in
            let parameters: [String: Any] = ["inputExtent": CIVector(cgRect: window), "inputRadius": corner, "inputColor": color]
            return (CIFilter(name: filter, parameters: parameters.merging(extra) { first, _ in first })?.outputImage ?? CIImage.empty()).cropped(to: margin)
        }
        let mask = tilt(shape(.white, "CIRoundedRectangleGenerator", [:]))
        let depth = diveFrom + (1 - diveFrom) * progress
        var seen = next.transformed(by: about(CGPoint(x: frame.midX, y: frame.midY), scale: depth, onto: CGPoint(x: window.midX, y: window.midY)))
        let blur = diveBlur * unit * (1 - progress)
        if blur >= 0.3 {
            seen = seen.clampedToExtent().applyingGaussianBlur(sigma: blur)
        }
        var image = seen.cropped(to: frame).applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: plane, kCIInputMaskImageKey: mask])
        let rim = 1 - min(max((progress - 0.5) / 0.4, 0), 1)
        if rim > 0 {
            let light = CIColor(red: 1, green: 1, blue: 1, alpha: diveRim.opacity * rim)
            image = tilt(shape(light, "CIRoundedRectangleStrokeGenerator", ["inputWidth": diveRim.width * unit * pow(zoom, 0.5)])).composited(over: image)
        }
        return image.cropped(to: frame)
    }

    /// How many times closer a dive into `source` ends: it covers the frame, a little past it.
    static func diveReach(of source: CGRect, size: CGSize) -> Double {
        max(size.width / max(source.width, 1), size.height / max(source.height, 1), 1) * diveOvershoot
    }

    /// `before` `progress` of the way melted into `next` by its own light, its front in `palette`'s deepest and palest
    /// colours (the haze's, from the brand).
    static func melted(_ before: CIImage, into next: CIImage, progress: Double, palette: FieldPalette?, size: CGSize) -> CIImage {
        let frame = CGRect(origin: .zero, size: size)
        let unit = size.height / 1080
        guard let kernel = FieldRenderer.kernel(named: "meltSeam") else { return before.fading(to: 1 - progress).composited(over: next) }
        let order = before.clampedToExtent().applyingGaussianBlur(sigma: meltOrderBlur * unit).cropped(to: frame)
        let colors = palette?.colors ?? []
        let vector = { (color: RGBAColor?) in CIVector(x: color?.red ?? 1, y: color?.green ?? 1, z: color?.blue ?? 1, w: 1) }
        let drip = meltDrip * unit
        let arguments: [Any] = [
            before.clampedToExtent(), next.clampedToExtent(), order.clampedToExtent(),
            CIVector(x: progress, y: meltFront, z: drip, w: max(meltGrain * unit, 1)),
            CIVector(x: size.width, y: size.height, z: meltByPlace, w: meltBreak), vector(colors.last), vector(colors.dropFirst(2).first)
        ]
        return kernel.apply(extent: frame, roiCallback: { index, rect in index == 0 ? rect.insetBy(dx: 0, dy: -drip - 1) : rect }, arguments: arguments)
            ?? next
    }

    /// Where an expand or dive seam into scene `index` opens from, in output pixels: the box of the last layer the scene before
    /// clicked, where it is `time` into the seam (that scene goes on under it, its camera drifting); without a click, the
    /// frame's middle.
    static func expandSource(into index: Int, at time: Double = 0, plan: MotionPlan) -> CGRect {
        let (width, height) = (Double(plan.outputSize.width), Double(plan.outputSize.height))
        let middle = CGRect(x: width * (1 - expandMiddle) / 2, y: height * (1 - expandMiddle) / 2, width: width * expandMiddle, height: height * expandMiddle)
        guard index > 0, case let scene = plan.scenes[index - 1],
              let last = clickTargets(of: scene, at: scene.duration + time, plan: plan).max(by: { pressed($0.clicks) < pressed($1.clicks) }),
              let minX = last.corners.map(\.x).min(), let maxX = last.corners.map(\.x).max(),
              let minY = last.corners.map(\.y).min(), let maxY = last.corners.map(\.y).max() else { return middle }
        let scale = plan.outputScale
        return CGRect(x: minX * scale, y: (plan.canvas.height - maxY) * scale, width: (maxX - minX) * scale, height: (maxY - minY) * scale)
    }

    /// How far a stack's, an expand's or a dive's moving edges travel while a shutter `shutter` long is open into scene
    /// `index`, in output pixels, so they're motion blurred as a layer moving as fast would be: a dive's at half the frame's
    /// height from its middle, magnified log-evenly.
    static func seamTravel(into index: Int, at time: Double, across shutter: Double, plan: MotionPlan) -> Double {
        let size = plan.outputSize
        guard let transition = plan.scenes[index].transition, [.stack, .expand, .dive].contains(transition.seam), time < transition.duration else { return 0 }
        let (opens, closes) = (transition.progress(at: time - shutter / 2), transition.progress(at: time + shutter / 2))
        guard transition.seam == .dive else { return abs(closes - opens) * size.height }
        return abs(closes - opens) * log(diveReach(of: expandSource(into: index, at: time, plan: plan), size: size)) * size.height / 2
    }

    private static func pressed(_ clicks: [MotionPlan.Click]) -> Double {
        clicks.map(\.press).max() ?? 0
    }

    /// Scaling by `scale` about `point`, then moving `point` onto `onto`.
    private static func about(_ point: CGPoint, scale: Double, onto: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: -point.x, y: -point.y).concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: onto.x, y: onto.y))
    }

    /// `image` on a plane turned `angle` degrees about the upright through `point`, seen from ``diveDistance`` frame heights away.
    private static func tilted(_ image: CIImage, about point: CGPoint, angle: Double, size: CGSize) -> CIImage {
        let extent = image.extent
        guard abs(angle) > 0.01, !extent.isInfinite, !extent.isEmpty else { return image }
        let (turn, distance) = (angle * .pi / 180, diveDistance * size.height)
        let place = { (left: Double, bottom: Double) -> CIVector in
            let across = left - point.x
            let depth = distance / (distance + across * sin(turn))
            return CIVector(x: point.x + across * cos(turn) * depth, y: point.y + (bottom - point.y) * depth)
        }
        return image.applyingFilter("CIPerspectiveTransform", parameters: [
            "inputTopLeft": place(extent.minX, extent.maxY), "inputTopRight": place(extent.maxX, extent.maxY),
            "inputBottomRight": place(extent.maxX, extent.minY), "inputBottomLeft": place(extent.minX, extent.minY)
        ])
    }

    /// `image` (a whole frame) `progress` of the way behind what comes over it: grown by `growth` of its size about `point`,
    /// darkened and blurred; on a light film's ground, darkened less (``recedeShadeLight``).
    private static func receded(_ image: CIImage, about point: CGPoint, growth: Double, progress: Double, isLight: Bool) -> CIImage {
        let (size, bounds) = (image.extent.size, image.extent)
        var image = image.transformed(by: about(point, scale: 1 + growth * progress, onto: point))
        let blur = recedeBlur * size.height / 1080 * progress
        if blur >= 0.3 {
            image = image.clampedToExtent().applyingGaussianBlur(sigma: blur)
        }
        let shade = CIImage(color: .black).cropped(to: bounds).fading(to: (isLight ? recedeShadeLight : recedeShade) * progress)
        return shade.composited(over: image.cropped(to: bounds))
    }

    /// `image` cut to `rect` with round corners, over its soft shadow.
    private static func framed(_ image: CIImage, in rect: CGRect, radius: Double, size: CGSize) -> CIImage {
        let unit = size.height / 1080
        let corner = min(radius, min(rect.width, rect.height) / 2)
        let shape = { (color: CIColor, rect: CGRect) in
            CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
                "inputExtent": CIVector(cgRect: rect), "inputRadius": corner, "inputColor": color
            ])?.outputImage ?? CIImage.empty()
        }
        let card = image.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: shape(.white, rect)])
        let shadow = shape(.black, rect.offsetBy(dx: 0, dy: -cardShadow.offset * unit))
            .applyingGaussianBlur(sigma: cardShadow.radius * unit).cropped(to: CGRect(origin: .zero, size: size))
            .fading(to: cardShadow.opacity)
        return card.composited(over: shadow)
    }

    /// A stack's scene before sinks to 0.92 of its size; the card's corners are a sheet's, square once it covers the frame.
    static let stackSink = 0.08
    static let stackRadius = 0.04

    /// An expand's scene before dives a quarter closer; its rectangle's corners start at a third of its shorter side (a
    /// pill's or a card's); without a click it opens from the middle 30 % of the frame.
    static let expandDive = 0.25
    static let expandRadius = 0.3
    static let expandMiddle = 0.3

    /// A dive ends a tenth past covering the frame, turns up to 16° on the way, seen from 2.5 frame heights; the next scene
    /// comes up from 0.6 of its size out of a 14 px blur (1080p), behind a 2.5 px rim at 0.7.
    static let diveOvershoot = 1.1
    static let diveTilt = 16.0
    static let diveDistance = 2.5
    static let diveFrom = 0.6
    static let diveBlur = 14.0
    static let diveRim = (width: 2.5, opacity: 0.7)

    /// A melt goes in the order of its scene's light blurred 18 px (1080p), so it melts in patches, and two fifths by place from
    /// the top left, so a plain frame still has a front crossing it (by light alone, a white frame went at once, all grain);
    /// its front spans 0.1 of the order, broken by 2 px grain a tenth as deep; what goes runs down 14 px.
    static let meltOrderBlur = 18.0
    static let meltByPlace = 0.4
    static let meltFront = 0.1
    static let meltBreak = 0.1
    static let meltDrip = 14.0
    static let meltGrain = 2.0

    /// What goes behind darkens by up to this much and blurs up to this many pixels at 1080p; a card's shadow.
    static let recedeShade = 0.55

    /// Over white, 0.55 of black turned the page behind a sheet a dirty grey: a light film's dims as a light UI's backdrop does.
    static let recedeShadeLight = 0.15
    static let recedeBlur = 8.0
    static let cardShadow = (radius: 30.0, offset: 10.0, opacity: 0.6)
}
