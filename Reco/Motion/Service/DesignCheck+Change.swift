//
//  DesignCheck+Change.swift
//  Reco
//

import CoreGraphics
import Foundation

/// How often the picture changes as a whole (spec 0021). Read at 32 × 18, half a second apart, parts rising into a card, a
/// creep or a slow arc hardly register; a menu opening, a line typed big, a card morphing, a cut or a whip do. The films the
/// user liked change their picture all the time; the ones they found static don't, though their pixels kept changing.
nonisolated extension DesignCheck {

    /// The picture is read this small, ``changeRate`` times a second.
    static let changeSize = (width: 32, height: 18)
    static let changeRate = 10.0

    /// Frames this far apart are compared.
    static let changeSpan = 0.5

    /// A picture whose luma changes by less than this on average (of 255) over ``changeSpan`` stands still.
    static let leastChange = 2.0

    /// The share of a film whose picture may stand still. Measured: Cal.com's story film 11 %, the Spotify Jam film 19 %, Orca
    /// v6 21 %, Cal.com's flow film 22 %; Cardboard's second, third and fifth films, which the user found static, 64, 61 and 40 %.
    static let mostStill = 0.25

    /// The longest a scene's picture may stand still, the end card aside: Spotify Jam's longest is 0.7 s, Cardboard 5's 1.8 s.
    static let longestStill = 1.0

    /// The film's and its scenes' still pictures. `levels` are the frames' lumas at ``changeSize``, ``changeRate`` a second
    /// from 0; `scenes` are each scene's id and start.
    static func stillPictures(levels: [[Double]], scenes: [(id: String, start: Double)]) -> [String] {
        let span = Int((changeSpan * changeRate).rounded())
        guard levels.count > span, let last = scenes.last else { return [] }
        let still = (span..<levels.count).map { index in
            zip(levels[index], levels[index - span]).reduce(0.0) { $0 + abs($1.0 - $1.1) } / Double(levels[index].count) < leastChange
        }
        let time = { (index: Int) in Double(index + span) / changeRate }
        var findings: [String] = []
        // Runs of still frames, by the scene each ends in
        var run: (start: Int, length: Int)?
        var longest: [String: (start: Double, length: Double)] = [:]
        for index in Array(still.indices) + [still.count] {
            if index < still.count, still[index] {
                run = (run?.start ?? index, (run?.length ?? 0) + 1)
                continue
            }
            guard let current = run else { continue }
            run = nil
            // The picture stood still from the earlier frame of its first comparison to its last frame
            let (start, end) = (time(current.start) - changeSpan, time(current.start + current.length - 1))
            guard let scene = scenes.last(where: { $0.start <= end - 1e-6 }), scene.id != last.id || scenes.count == 1 else { continue }
            let length = end - max(start, scene.start)
            if length > longestStill, length > longest[scene.id]?.length ?? 0 {
                longest[scene.id] = (max(start, scene.start) - scene.start, length)
            }
        }
        let share = Double(still.count { $0 }) / Double(still.count)
        if share > mostStill {
            findings.append("The picture hardly changes in \(Int((share * 100).rounded()))% of the film (the films this bar comes from: 11–22 %): "
                + "a part rising into a card, a slow push or an arc doesn't read as motion; a click opening a menu, a line typed big, a card "
                + "morphing or flooding, a whip to the next thing does.")
        }
        for scene in scenes {
            guard let still = longest[scene.id] else { continue }
            let (from, length) = (still.start.formatted(.number.precision(.fractionLength(1))), still.length.formatted(.number.precision(.fractionLength(1))))
            findings.append("\(scene.id): the picture stands still from \(from) s for \(length) s: make something big happen in it or end it sooner.")
        }
        return findings
    }

    /// A frame's luma at ``changeSize``, averaged over 3 × 3 pixels drawn at three times the size.
    static func levels(of image: CGImage) -> [Double]? {
        let (width, height) = (changeSize.width * 3, changeSize.height * 3)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        let luma = { (column: Int, row: Int) -> Double in
            let pixel = (row * width + column) * 4
            let (red, green, blue) = (Double(bytes[pixel]), Double(bytes[pixel + 1]), Double(bytes[pixel + 2]))
            return 0.2126 * red + 0.7152 * green + 0.0722 * blue
        }
        var levels: [Double] = []
        for row in 0..<changeSize.height {
            for column in 0..<changeSize.width {
                let sum = (0..<9).reduce(0.0) { sum, index in sum + luma(column * 3 + index % 3, row * 3 + index / 3) }
                levels.append(sum / 9)
            }
        }
        return levels
    }
}
