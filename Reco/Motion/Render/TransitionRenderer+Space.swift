//
//  TransitionRenderer+Space.swift
//  Reco
//

import CoreImage

/// Graphic seams that move whole frames in space (spec 0019): split apart, turned over as a card or on a cube, a flash of the
/// brand's colour, a stretch.
nonisolated extension TransitionRenderer {

    /// The scene before split down its middle (or across it), its halves sliding apart on the seam's curve with an edge of
    /// `edge.color`, the next coming up behind them from 0.9×, darkened by `edge.shade`.
    static func split(
        _ scenes: (before: CIImage, next: CIImage), progress: Double, vertical: Bool, edge: (color: CIVector, shade: Double), size: CGSize
    ) -> CIImage {
        let color = edge.color
        let eased = ease(progress)
        let unit = size.height / 1080
        let (width, height) = (size.width, size.height)
        let halves = vertical
            ? [CGRect(x: 0, y: 0, width: width / 2, height: height), CGRect(x: width / 2, y: 0, width: width / 2, height: height)]
            : [CGRect(x: 0, y: 0, width: width, height: height / 2), CGRect(x: 0, y: height / 2, width: width, height: height / 2)]
        let travel = (vertical ? width : height) / 2 * eased
        let rim = CIImage(color: CIColor(red: color.x, green: color.y, blue: color.z))
        // Its edge widens as the doors part, from nothing
        let thick = splitEdge * unit * min(eased / splitEdgeGrows, 1)
        var image = scaled(scenes.next, by: splitFrom + (1 - splitFrom) * eased, size: size)
        image = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size)).fading(to: edge.shade * (1 - eased)).composited(over: image)
        for (index, half) in halves.enumerated() {
            let away = index == 0 ? -travel : travel
            let shift = vertical ? CGAffineTransform(translationX: away, y: 0) : CGAffineTransform(translationX: 0, y: away)
            // Its inner edge in the brand's colour
            let inner = vertical
                ? CGRect(x: index == 0 ? half.maxX - thick : half.minX, y: 0, width: thick, height: height)
                : CGRect(x: 0, y: index == 0 ? half.maxY - thick : half.minY, width: width, height: thick)
            let door = rim.cropped(to: inner).composited(over: scenes.before.cropped(to: half))
            image = door.transformed(by: shift).composited(over: image)
        }
        return image
    }

    /// The frame turned over as a card about its upright: shrinking to 0.82× half way, the scene before on its face until it's
    /// edge on, the next on its back, shaded as it turns from the light, over `ground`.
    static func flipped(_ scenes: (before: CIImage, next: CIImage), progress: Double, turn: Double, ground: CIColor, size: CGSize) -> CIImage {
        let eased = ease(progress)
        let angle = 180 * eased
        let (image, facing) = angle <= 90 ? (scenes.before, angle) : (scenes.next, angle - 180)
        let scale = 1 - cardShrink * sin(.pi * eased)
        let card = carded(image, scale: scale, size: size)
        let theta = turn * facing * .pi / 180
        let quad = card.extent.corners.map { corner in
            let (across, rise) = (corner.x - size.width / 2, corner.y - size.height / 2)
            let depth = cardDistance * size.height / (cardDistance * size.height + across * sin(theta))
            return CGPoint(x: size.width / 2 + across * cos(theta) * depth, y: size.height / 2 + rise * depth)
        }
        let shade = CIImage(color: .black).cropped(to: card.extent).fading(to: cardShade * abs(sin(theta)))
        let face = shade.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: card]).composited(over: card)
        return projected(face, onto: quad).composited(over: CIImage(color: ground).cropped(to: CGRect(origin: .zero, size: size)))
    }

    /// The frame turning away on a cube about an upright behind it, the next scene on the face coming round, both shaded as they
    /// turn from the light; the cube drawn smaller half way so its edge shows, over `ground`.
    static func cubed(_ scenes: (before: CIImage, next: CIImage), progress: Double, turn: Double, ground: CIColor, size: CGSize) -> CIImage {
        let eased = ease(progress)
        let scale = 1 - cardShrink * sin(.pi * eased)
        let (half, rise) = (size.width / 2 * scale, size.height / 2 * scale)
        let distance = cardDistance * size.height
        let leaving = turn * 90 * eased * .pi / 180
        let faces = [(scenes.before, leaving), (scenes.next, leaving - turn * .pi / 2)]
        // A face at `angle`, its points `half` in front of the upright: `along` it and `rise` up from the frame's middle
        let place = { (along: Double, rise: Double, angle: Double) -> CGPoint in
            let (across, depth) = (along * cos(angle) + half * sin(angle), along * sin(angle) - half * cos(angle))
            let seen = distance / (distance + half + depth)
            return CGPoint(x: size.width / 2 + across * seen, y: size.height / 2 + rise * seen)
        }
        var image = CIImage(color: ground).cropped(to: CGRect(origin: .zero, size: size))
        // The farther face first
        for (frame, angle) in faces.sorted(by: { -cos($0.1) > -cos($1.1) }) where cos(angle) > 0.001 {
            let flat = scaled(frame, by: scale, size: size).cropped(to: CGRect(x: size.width / 2 - half, y: size.height / 2 - rise, width: 2 * half, height: 2 * rise))
            let shade = CIImage(color: .black).cropped(to: flat.extent).fading(to: cubeShade * (1 - cos(angle)))
            let quad = flat.extent.corners.map { place($0.x - size.width / 2, $0.y - size.height / 2, angle) }
            image = projected(shade.composited(over: flat), onto: quad).composited(over: image)
        }
        return image
    }

    /// A flash of `color` up in the seam's first quarter and gone by its end, the cut under it at 0.3; the scene before pushed in
    /// as it flashes, the next settling from 1.06×.
    static func flashed(_ scenes: (before: CIImage, next: CIImage), progress: Double, color: CIVector, size: CGSize) -> CIImage {
        let rising = min(progress / flashPeak, 1)
        let level = progress < flashHold ? 1 - pow(1 - rising, 2) : 1 - ease((progress - flashHold) / (1 - flashHold))
        let shown = progress < flashCut
            ? scaled(scenes.before, by: 1 + 0.04 * rising, size: size)
            : scaled(scenes.next, by: 1 + (flashFrom - 1) * (1 - MotionEasing.enterFast.progress((progress - flashCut) / (1 - flashCut), duration: 1)), size: size)
        let light = CIImage(color: CIColor(red: color.x, green: color.y, blue: color.z)).cropped(to: CGRect(origin: .zero, size: size))
        return light.fading(to: level).composited(over: shown)
    }

    /// The scene before stretched away along one axis, faster and faster and blurred along it, then the next snapping back from
    /// stretched, out-expo; its edges drawn on across the frame.
    static func stretched(_ scenes: (before: CIImage, next: CIImage), progress: Double, horizontal: Bool, size: CGSize) -> CIImage {
        let unit = size.height / 1080
        let leaving = progress < stretchCut
        let (image, amount) = leaving
            ? (scenes.before, pow(progress / stretchCut, 3))
            : (scenes.next, 1 - MotionEasing.enterFast.progress((progress - stretchCut) / (1 - stretchCut), duration: 1))
        let (along, across) = (1 + stretchMost * amount, 1 - stretchSquash * amount)
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        let transform = CGAffineTransform(translationX: -middle.x, y: -middle.y)
            .concatenating(horizontal ? CGAffineTransform(scaleX: along, y: across) : CGAffineTransform(scaleX: across, y: along))
            .concatenating(CGAffineTransform(translationX: middle.x, y: middle.y))
        var stretched = image.clampedToExtent().transformed(by: transform)
        let blur = stretchBlur * unit * amount * amount
        if blur >= 0.5 {
            stretched = stretched.applyingFilter("CIMotionBlur", parameters: [kCIInputRadiusKey: blur, kCIInputAngleKey: horizontal ? 0 : Double.pi / 2])
        }
        return stretched.cropped(to: CGRect(origin: .zero, size: size))
    }

    // MARK: - Helpers

    /// `image` magnified `scale` times about the frame's middle.
    private static func scaled(_ image: CIImage, by scale: Double, size: CGSize) -> CIImage {
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        return image.transformed(by: CGAffineTransform(translationX: -middle.x, y: -middle.y)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale)).concatenating(CGAffineTransform(translationX: middle.x, y: middle.y)))
    }

    /// The frame drawn `scale` times its size about its middle as a card with round corners.
    private static func carded(_ image: CIImage, scale: Double, size: CGSize) -> CIImage {
        let (width, height) = (Double(size.width), Double(size.height))
        let rect = CGRect(x: width * (1 - scale) / 2, y: height * (1 - scale) / 2, width: width * scale, height: height * scale)
        let radius: Double = cardRadius * Double(size.height) * (1 - scale) / cardShrink
        let mask = CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
            "inputExtent": CIVector(cgRect: rect), "inputRadius": radius, "inputColor": CIColor.white
        ])?.outputImage ?? CIImage(color: .white).cropped(to: rect)
        return scaled(image, by: scale, size: size).applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: mask]).cropped(to: rect)
    }

    /// `image`'s extent mapped onto `quad` (its bottom-left, bottom-right, top-right, top-left corners).
    private static func projected(_ image: CIImage, onto quad: [CGPoint]) -> CIImage {
        image.applyingFilter("CIPerspectiveTransform", parameters: [
            "inputBottomLeft": CIVector(cgPoint: quad[0]), "inputBottomRight": CIVector(cgPoint: quad[1]),
            "inputTopRight": CIVector(cgPoint: quad[2]), "inputTopLeft": CIVector(cgPoint: quad[3])
        ])
    }

    /// A split's next scene comes up from 0.9× and half dark (on a light ground, as a stack's); its doors' inner edges grow to 6 px of the brand's colour at 1080p
    /// by a tenth of the way open.
    static let splitFrom = 0.9
    static let splitShade = 0.5
    static let splitEdge = 6.0
    static let splitEdgeGrows = 0.1

    /// A card or cube shrinks to 0.82× half way, seen from 2.2 frame heights; its corners grow to 3 % of the frame's height as it
    /// shrinks; turned edge on, a card's face darkens by 0.45, a cube's by 0.6.
    static let cardShrink = 0.18
    static let cardDistance = 2.2
    static let cardRadius = 0.03
    static let cardShade = 0.45
    static let cubeShade = 0.6

    /// A flash is up by 0.25 of its seam, held to 0.35, gone at its end; the cut under it is at 0.3 and the next settles from 1.06×.
    static let flashPeak = 0.25
    static let flashHold = 0.35
    static let flashCut = 0.3
    static let flashFrom = 1.06

    /// A stretch cuts 0.45 of the way through, at 4× along and 0.9× across, blurred 60 px (1080p).
    static let stretchCut = 0.45
    static let stretchMost = 3.0
    static let stretchSquash = 0.1
    static let stretchBlur = 60.0
}

nonisolated private extension CGRect {

    /// Bottom left, bottom right, top right, top left.
    var corners: [CGPoint] {
        [CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: minY), CGPoint(x: maxX, y: maxY), CGPoint(x: minX, y: maxY)]
    }
}
