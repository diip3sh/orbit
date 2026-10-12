//
//  DesignCheck.swift
//  Reco
//

import CoreGraphics
import Foundation

/// What the rules can only see in pixels, checked on a frame of every scene (spec 0011, *Rules*):
/// a frame that shows next to nothing, an accent covering more than a sliver of the frame, and a
/// scene that opens on its bare ground.
nonisolated enum DesignCheck {

    /// How soon after its cut a scene must show something: a Linear film cut every 2 s flashed its
    /// field between shots, its UI fading in from 0.2 s over 0.6 s.
    static let openingCheck = 0.3

    /// What counts as showing: a layer at least half there, covering this share of the frame.
    static let smallestShown = 0.002

    /// Frames are read this small: shares of a frame don't need more.
    static let sampleSize = (width: 96, height: 54)

    /// A frame whose luma varies less than this (standard deviation, 0–1) is one flat color.
    static let flatness = 0.02

    /// One accent, on at most ~5% of the frame's pixels.
    static let largestAccentShare = 0.05

    /// How close a pixel is to the accent to count as it: a distance in sRGB, 0–√3.
    static let accentDistance = 0.12

    static func findings(in frames: [CGImage], at moments: [ContactSheet.Moment], accent: RGBAColor?) -> [String] {
        zip(frames, moments).flatMap { frame, moment in
            guard let pixels = pixels(of: frame) else { return [String]() }
            let label = "\(moment.scene) at \(moment.time.formatted(.number.precision(.fractionLength(1)))) s"
            var findings: [String] = []
            if deviation(of: pixels) < flatness {
                findings.append("\(label) is nearly one flat color: nothing shows.")
            }
            if let accent {
                let share = Self.share(of: accent, in: pixels)
                if share > largestAccentShare {
                    findings.append("\(label): the accent covers \(Int((share * 100).rounded()))% of the frame; keep it to a sliver, under 5%.")
                }
            }
            return findings
        }
    }

    /// The scenes of `plan` (named by `scenes`) with nothing on screen ``openingCheck`` after their cut.
    static func bareOpenings(in plan: MotionPlan, scenes: [String]) -> [String] {
        let frame = plan.canvas.width * plan.canvas.height
        return zip(plan.scenes, scenes).compactMap { scene, id in
            guard scene.duration > openingCheck else { return nil }
            let shown = plan.placements(of: scene, at: openingCheck).contains { placement in
                placement.opacity >= 0.5 && area(of: placement.corners) >= smallestShown * frame
            }
            return shown ? nil : "\(id) shows only its ground for its first \(openingCheck.formatted()) s: bring its first layer in at 0.1 s."
        }
    }

    /// A camera at least this close is a macro on a control, where the frame crops the rest of the box, as Lovable's did.
    static let macroMagnification = 2.0

    /// How far past the frame's edge text may reach unnoticed, as a share of the frame.
    static let cutTolerance = 0.01

    /// The scenes of `plan` whose text runs off the frame in their middle: the first Orca films cut a terminal's lines
    /// at both sides, a row of agents at its ends and a dialog at its top. A voice line runs off on purpose, and a macro
    /// crops what's round its control.
    static func cutText(in plan: MotionPlan, scenes: [String]) -> [String] {
        let frame = CGRect(origin: .zero, size: plan.canvas)
            .insetBy(dx: -plan.canvas.width * cutTolerance, dy: -plan.canvas.height * cutTolerance)
        return zip(plan.scenes, scenes).compactMap { scene, id in
            let time = scene.duration / 2
            guard plan.camera(of: scene, at: time).magnification < macroMagnification else { return nil }
            let isCut = plan.placements(of: scene, at: time).contains { placement in
                let layer = scene.layers[placement.layer]
                guard !layer.parts.isEmpty, layer.reveal?.style != .voice, placement.opacity >= 0.5 else { return false }
                return placement.corners.contains { !frame.contains($0) }
            }
            return isCut ? "\(id): text runs off the frame; show the whole thing, or put the camera on one control at 2× or closer." : nil
        }
    }

    /// The scenes of `plan` with one text drawn over another, or a glyph over text, as they end, everything arrived: an Orca
    /// film left a diff's five line numbers at one place, mid-card, and another a check on the "M" of "Merged". A text counts
    /// as over another when its middle is inside it, a glyph when more than ``glyphCover`` of its box is in the text's.
    /// `document` is the one the plan was built from, its shots laid out (``DocumentExpansion/expanded(_:sizes:)``).
    static func overlappingText(in plan: MotionPlan, document: MotionDocument) -> [String] {
        zip(plan.scenes, document.scenes).compactMap { scene, source in
            let contents = MotionPlan.contents(of: source.layers)
            let shown = plan.placements(of: scene, at: scene.duration * settled).filter { $0.opacity >= 0.5 }
            let texts = shown.filter { !scene.layers[$0.layer].parts.isEmpty }.map(\.corners)
            let glyphs = shown.filter { placement in
                guard contents.indices.contains(placement.layer), case .shape(let shape) = contents[placement.layer] else { return false }
                return shape.isGlyph
            }.map(\.corners)
            let middles = texts.map { corners in
                CGPoint(x: corners.map(\.x).reduce(0, +) / Double(corners.count), y: corners.map(\.y).reduce(0, +) / Double(corners.count))
            }
            if texts.indices.contains(where: { index in middles.indices.contains { $0 != index && contains(texts[index], middles[$0]) } }) {
                return "\(source.id): two texts are drawn over each other; give each its own place."
            }
            if glyphs.contains(where: { glyph in texts.contains { cover(of: glyph, by: $0) > glyphCover } }) {
                return "\(source.id): a glyph is drawn over text; move it clear of the text's edge."
            }
            return nil
        }
    }

    /// How much of a glyph's box may be inside a text's: a check on a label's first letter covered a third.
    static let glyphCover = 0.15

    /// The share of `quad`'s box inside `other`'s.
    private static func cover(of quad: [CGPoint], by other: [CGPoint]) -> Double {
        let box = { (corners: [CGPoint]) in
            CGRect(x: corners.map(\.x).min() ?? 0, y: corners.map(\.y).min() ?? 0,
                   width: (corners.map(\.x).max() ?? 0) - (corners.map(\.x).min() ?? 0), height: (corners.map(\.y).max() ?? 0) - (corners.map(\.y).min() ?? 0))
        }
        let (inner, outer) = (box(quad), box(other))
        let overlap = inner.intersection(outer)
        return overlap.isNull || inner.width * inner.height <= 0 ? 0 : overlap.width * overlap.height / (inner.width * inner.height)
    }

    /// How far into a scene its texts are checked against each other: they've arrived, and nothing has left yet.
    static let settled = 0.9

    /// Whether a convex quad holds `point`: on the same side of all its edges.
    private static func contains(_ corners: [CGPoint], _ point: CGPoint) -> Bool {
        let sides = corners.indices.map { index in
            let (start, end) = (corners[index], corners[(index + 1) % corners.count])
            return (end.x - start.x) * (point.y - start.y) - (end.y - start.y) * (point.x - start.x)
        }
        return sides.allSatisfy { $0 >= 0 } || sides.allSatisfy { $0 <= 0 }
    }

    /// A quad's area by the shoelace formula.
    private static func area(of corners: [CGPoint]) -> Double {
        let twice = corners.indices.reduce(0.0) { sum, index in
            let (point, next) = (corners[index], corners[(index + 1) % corners.count])
            return sum + point.x * next.y - next.x * point.y
        }
        return abs(twice) / 2
    }

    /// The frame's pixels as sRGB components from 0 to 1, three a pixel.
    static func pixels(of image: CGImage) -> [Double]? {
        let (width, height) = sampleSize
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        return (0..<width * height).flatMap { pixel in
            (0..<3).map { Double(bytes[pixel * 4 + $0]) / 255 }
        }
    }

    /// The standard deviation of the pixels' luma (Rec. 709 weights).
    static func deviation(of pixels: [Double]) -> Double {
        let weights: [Double] = [0.2126, 0.7152, 0.0722]
        let lumas: [Double] = stride(from: 0, to: pixels.count, by: 3).map { index in
            (0..<3).reduce(0.0) { $0 + weights[$1] * pixels[index + $1] }
        }
        guard !lumas.isEmpty else { return 0 }
        let mean = lumas.reduce(0, +) / Double(lumas.count)
        let variance = lumas.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(lumas.count)
        return variance.squareRoot()
    }

    /// The share of the pixels within ``accentDistance`` of `accent`.
    static func share(of accent: RGBAColor, in pixels: [Double]) -> Double {
        let count = pixels.count / 3
        guard count > 0 else { return 0 }
        let matching = stride(from: 0, to: pixels.count, by: 3).filter { index in
            let (red, green, blue) = (pixels[index] - accent.red, pixels[index + 1] - accent.green, pixels[index + 2] - accent.blue)
            return (red * red + green * green + blue * blue).squareRoot() < accentDistance
        }.count
        return Double(matching) / Double(count)
    }
}
