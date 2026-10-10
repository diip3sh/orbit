//
//  MotionFrameRenderer+Seams.swift
//  Reco
//

import CoreImage

/// Seams that move whole frames as things: the next scene rising on a card over the one before (``MotionSeam/stack``), or
/// opening out of what it clicked (``MotionSeam/expand``).
nonisolated extension MotionFrameRenderer {

    /// The next scene `progress` of the way up from below on a card, the scene before sinking back under it.
    static func stacked(_ before: CIImage, under next: CIImage, progress: Double, size: CGSize) -> CIImage {
        let card = CGRect(origin: CGPoint(x: 0, y: -size.height * (1 - progress)), size: size)
        let back = receded(before, about: CGPoint(x: size.width / 2, y: size.height / 2), scale: 1 - stackSink * progress, progress: progress, size: size)
        let shown = next.transformed(by: CGAffineTransform(translationX: 0, y: card.minY))
        return framed(shown, in: card, radius: stackRadius * size.height * (1 - progress), size: size).composited(over: back)
    }

    /// The next scene `progress` of the way out of `source` (output pixels) to the whole frame, the scene before diving
    /// towards it.
    static func expanded(_ before: CIImage, into next: CIImage, from source: CGRect, progress: Double, size: CGSize) -> CIImage {
        let mix = { (start: Double, end: Double) in start + (end - start) * progress }
        let rect = CGRect(x: mix(source.minX, 0), y: mix(source.minY, 0), width: mix(source.width, size.width), height: mix(source.height, size.height))
        // The next scene fills the rectangle, as an app's first screen grows out of its icon
        let fill = max(rect.width / size.width, rect.height / size.height)
        let shown = next.transformed(by: CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
            .concatenating(CGAffineTransform(scaleX: fill, y: fill))
            .concatenating(CGAffineTransform(translationX: rect.midX, y: rect.midY)))
        let back = receded(before, about: CGPoint(x: source.midX, y: source.midY), scale: 1 + expandDive * progress, progress: progress, size: size)
        let radius = min(source.width, source.height) * expandRadius * (1 - progress)
        return framed(shown, in: rect, radius: radius, size: size).composited(over: back)
    }

    /// Where an expand seam into scene `index` opens from, in output pixels: the box of the last layer the scene before
    /// clicked, where it is at that scene's end; without a click, the frame's middle.
    static func expandSource(into index: Int, plan: MotionPlan) -> CGRect {
        let (width, height) = (Double(plan.outputSize.width), Double(plan.outputSize.height))
        let middle = CGRect(x: width * (1 - expandMiddle) / 2, y: height * (1 - expandMiddle) / 2, width: width * expandMiddle, height: height * expandMiddle)
        guard index > 0, case let scene = plan.scenes[index - 1],
              let last = clickTargets(of: scene, at: scene.duration, plan: plan).max(by: { pressed($0.clicks) < pressed($1.clicks) }),
              let minX = last.corners.map(\.x).min(), let maxX = last.corners.map(\.x).max(),
              let minY = last.corners.map(\.y).min(), let maxY = last.corners.map(\.y).max() else { return middle }
        let scale = plan.outputScale
        return CGRect(x: minX * scale, y: (plan.canvas.height - maxY) * scale, width: (maxX - minX) * scale, height: (maxY - minY) * scale)
    }

    /// How far a stack's or an expand's moving edge travels while a shutter `shutter` long is open, in output pixels, so
    /// it's motion blurred as a layer moving as fast would be.
    static func seamTravel(of scene: MotionPlan.Scene, at time: Double, across shutter: Double, size: CGSize) -> Double {
        guard let transition = scene.transition, transition.seam == .stack || transition.seam == .expand, time < transition.duration else { return 0 }
        let (opens, closes) = (transition.progress(at: time - shutter / 2), transition.progress(at: time + shutter / 2))
        return abs(closes - opens) * size.height
    }

    private static func pressed(_ clicks: [MotionPlan.Click]) -> Double {
        clicks.map(\.press).max() ?? 0
    }

    /// `image` scaled by `scale` about `point`, darkened and blurred as it goes behind what comes over it.
    private static func receded(_ image: CIImage, about point: CGPoint, scale: Double, progress: Double, size: CGSize) -> CIImage {
        let bounds = CGRect(origin: .zero, size: size)
        let transform = CGAffineTransform(translationX: -point.x, y: -point.y)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: point.x, y: point.y))
        var image = image.transformed(by: transform)
        let blur = recedeBlur * size.height / 1080 * progress
        if blur >= 0.3 {
            image = image.clampedToExtent().applyingGaussianBlur(sigma: blur)
        }
        let shade = CIImage(color: .black).cropped(to: bounds).fading(to: recedeShade * progress)
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

    /// What goes behind darkens by up to this much and blurs up to this many pixels at 1080p; a card's shadow.
    static let recedeShade = 0.55
    static let recedeBlur = 8.0
    static let cardShadow = (radius: 30.0, offset: 10.0, opacity: 0.6)
}
