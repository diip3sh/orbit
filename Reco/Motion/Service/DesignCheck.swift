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
