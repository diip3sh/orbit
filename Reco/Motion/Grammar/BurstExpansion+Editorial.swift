//
//  BurstExpansion+Editorial.swift
//  Reco
//

import CoreGraphics
import Foundation

/// Editorial films' accents (spec 0017), measured on ElevenLabs' launch film: the dark beat's ring of stars and the dots born
/// round its sphere, laid beside the layer they surround, keyframed and seeded by its id.
nonisolated extension BurstExpansion {

    /// The stars (24.03–25.42 s): 12 dots 12 px across, 30° apart on a circle round the middle, turning clockwise as the
    /// speeds below (degrees a second) while its radius (shares of the frame's height) dips and opens; popping in over the
    /// first 0.25 s, shrinking away over the last 0.4 s as they spiral out.
    static let stars = 12
    static let starSide = 12.0
    static let starSpeeds: [(time: Double, value: Double)] = [
        (0, 132), (0.17, 93), (0.37, 63), (0.57, 42), (0.62, 37), (0.77, 41), (0.97, 51), (1.12, 61), (1.27, 82), (1.4, 104)
    ]
    static let starRadii: [(time: Double, value: Double)] = [(0, 0.363), (0.62, 0.35), (0.97, 0.358), (1.4, 0.418)]
    static let starsArrive = 0.25
    static let starsLeave = 0.4

    /// The dots (33.43–34.27 s): black squares 14 px across, shrinking to 9, on the lattice's corners (a 128 px step) between
    /// 240 and 960 px out, about a quarter of them. Born in a wave outwards (seconds by distance at 1080p), dying from the
    /// inside out, each flickering off and on for a frame at its birth and death.
    static let dotSide = 14.0
    static let dotEnd = 9.0 / 14
    static let dotShare = 0.27
    static let dotBirths: [(time: Double, value: Double)] = [(240, 0), (450, 0.07), (580, 0.12), (840, 0.15), (960, 0.34)]
    static let dotDeaths: [(time: Double, value: Double)] = [(240, 0.4), (330, 0.44), (400, 0.57), (700, 0.67), (960, 0.82)]

    // MARK: - Orbit

    static func orbit(_ move: MotionMove, number: Int, from source: Source) -> MotionLayer {
        let (layer, context) = (source.layer, source.context)
        let (start, duration) = MoveExpansion.timing(of: move, in: context)
        let stretch = duration / MoveExpansion.orbitDuration
        let (height, amount) = (context.canvas.height, move.intensity ?? 1)
        let side: Double = move.size.map { Double($0.width) } ?? starSide * context.unit
        let color = move.color ?? RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
        let shape = ShapeContent(size: CGSize(width: side, height: side), cornerRadius: side / 2, color: color)
        // The ring's turn so far, in degrees, at 30 Hz on the film's clock
        let count = max(Int((duration * 30).rounded(.up)), 1)
        let step = MoveExpansion.orbitDuration / Double(count)
        var turns = [0.0]
        for index in 1...count {
            let speed = (interpolated(starSpeeds, at: Double(index - 1) * step) + interpolated(starSpeeds, at: Double(index) * step)) / 2
            turns.append(turns[index - 1] + speed * step)
        }
        let group = "\(layer.id).orbit\(number)"
        let pieces = (0..<stars).map { index -> MotionLayer in
            var star = MotionLayer(id: "\(group).\(index)", content: .shape(shape))
            var keyframes: [MotionProperty: [Keyframe]] = [:]
            let first: Double = Double(index) * 360 / Double(stars) - 90
            for sample in 0...count {
                let fraction = Double(sample) / Double(count)
                let angle: Double = (first + turns[sample]) * .pi / 180
                let radius: Double = interpolated(starRadii, at: fraction * MoveExpansion.orbitDuration) * height * amount
                let time = start + fraction * duration
                keyframes[.positionX, default: []].append(Keyframe(time: time, value: radius * cos(angle)))
                keyframes[.positionY, default: []].append(Keyframe(time: time, value: radius * sin(angle)))
            }
            let (arrives, leaves) = (start + starsArrive * stretch * Double(index) / Double(stars - 1), start + duration - starsLeave * stretch)
            keyframes[.scale] = [
                Keyframe(time: arrives, value: 0.05, easing: .enterFast), Keyframe(time: arrives + 0.1, value: 1),
                Keyframe(time: leaves, value: 1, easing: .exit), Keyframe(time: start + duration, value: 0.05)
            ]
            keyframes[.opacity] = [
                Keyframe(time: arrives - 1e-3, value: 0, easing: .hold), Keyframe(time: arrives, value: 1),
                Keyframe(time: start + duration - 0.05, value: 1), Keyframe(time: start + duration, value: 0)
            ]
            star.keyframes = keyframes
            return star
        }
        return MotionLayer(id: group, content: .group(pieces), transform: Transform3D(position: centre(of: layer, before: start, sizes: source.sizes, context: context)))
    }

    // MARK: - Dots

    static func dots(_ move: MotionMove, number: Int, from source: Source) -> MotionLayer {
        let (layer, context) = (source.layer, source.context)
        let (start, duration) = MoveExpansion.timing(of: move, in: context)
        let stretch = duration / MoveExpansion.dotsDuration
        let (unit, amount) = (context.unit, move.intensity ?? 1)
        let side: Double = move.size.map { Double($0.width) } ?? dotSide * unit
        let color = move.color ?? RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
        let step = LatticeSetup.step * unit * amount
        let (inner, outer) = (dotBirths[0].time, dotBirths[dotBirths.count - 1].time)
        let group = "\(layer.id).dots\(number)"
        var random = SeededRandom(seed: seed(group))
        let reach = Int((outer * unit * amount / step).rounded(.up))
        var pieces: [MotionLayer] = []
        for row in -reach..<reach {
            for column in -reach..<reach {
                // The lattice's corners: its middle cell is centred on the layer
                let place = CGPoint(x: (Double(column) + 0.5) * step, y: (Double(row) + 0.5) * step)
                let distance = hypot(place.x, place.y) / (unit * amount)
                guard distance >= inner, distance <= outer, random.unit() < dotShare else { continue }
                let born = start + interpolated(dotBirths, at: distance) * stretch
                let dies = start + min(interpolated(dotDeaths, at: distance) + random.uniform(-0.03...0.03), MoveExpansion.dotsDuration) * stretch
                let frame = MoveExpansion.blinkFrame
                var dot = MotionLayer(
                    id: "\(group).\(pieces.count)", content: .shape(ShapeContent(size: CGSize(width: side, height: side), color: color)),
                    transform: Transform3D(position: [place.x, place.y, 0])
                )
                dot.keyframes = [
                    .scale: [Keyframe(time: born, value: 1), Keyframe(time: dies, value: dotEnd)],
                    .opacity: [(born - 1e-3, 0.0), (born, 1), (born + frame, 0), (born + 2 * frame, 1), (dies - 2 * frame, 0), (dies - frame, 1), (dies, 0)]
                        .map { Keyframe(time: $0.0, value: $0.1, easing: .hold) }
                ]
                pieces.append(dot)
            }
        }
        return MotionLayer(id: group, content: .group(pieces), transform: Transform3D(position: centre(of: layer, before: start, sizes: source.sizes, context: context)))
    }

    /// `points`' value at `time`, straight between them and held past either end.
    private static func interpolated(_ points: [(time: Double, value: Double)], at time: Double) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        guard time > first.time else { return first.value }
        guard time < last.time else { return last.value }
        let next = points.firstIndex { $0.time >= time } ?? points.count - 1
        let (before, after) = (points[next - 1], points[next])
        return before.value + (after.value - before.value) * (time - before.time) / (after.time - before.time)
    }
}
