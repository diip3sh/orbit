//
//  BurstExpansion.swift
//  Reco
//

import CoreGraphics
import Foundation

/// Motion design's accents as layers of their own (spec 0014): a burst's particles and a ripple's rings, laid
/// beside the layer they come out of and keyframed, seeded by its id so they fall the same way every time. Measured
/// on the Spotify Jam film's check (13.0–14.0 s): about 40 triangles thrown out across the frame in 0.2 s, sharp, drifting
/// and spinning, gone within a second; a thin ring hugging the disc. A ripple with a stroke is the flood's soft bands,
/// drawn inside its shape (``ShapeMorph/Band``).
nonisolated enum BurstExpansion {

    static let particles = 36
    static let duration = 1.2

    /// How far the farthest particle flies, as a share of the canvas's height, and how much farther across.
    static let reach = 0.6
    static let reachAcross = 1.4

    /// Particles' sides at 1080p.
    static let sides = 8.0...19.0

    /// Rings: two, 0.12 s apart, each opening past the layer's edge by this share of its shorter side.
    static let rings = 2
    static let ringStagger = 0.12
    static let ringReach = 0.5
    static let rippleDuration = 0.7
    static let ringWidth = 2.5

    /// A band's blur, as a share of its width.
    static let softBands = 0.35

    /// The layer accents come out of, and what placing them needs.
    nonisolated struct Source {
        let layer: MotionLayer
        let style: StyleTokens
        let sizes: [String: CGSize]
        let context: MoveContext
    }

    /// The groups `source`'s bursts and ripples add: particles drawn behind it, rings over it.
    static func accents(of source: Source) -> (behind: [MotionLayer], over: [MotionLayer]) {
        var accents: (behind: [MotionLayer], over: [MotionLayer]) = ([], [])
        for (index, move) in source.layer.moves.enumerated() {
            switch move.kind {
            case .burst: accents.behind.append(burst(move, number: index, from: source))
            case .ripple:
                if case .shape(let shape) = source.layer.content, ShapeMorph.isBand(move, on: shape) {
                    continue
                }
                accents.over.append(ripple(move, number: index, from: source))
            default: break
            }
        }
        return accents
    }

    /// Whether `id` is a burst's particles: drawn sharp at the frame's time under motion blur, as the film's are. Thrown
    /// across the frame in 0.2 s, a 180° shutter streaked them into rays.
    static func isParticles(_ id: String) -> Bool {
        id.split(separator: ".").last.map { $0.hasPrefix("burst") && $0.dropFirst(5).allSatisfy(\.isNumber) && $0.count > 5 } ?? false
    }

    private static func particlesID(of layer: String, number: Int) -> String {
        "\(layer).burst\(number)"
    }

    // MARK: - Burst

    private static func burst(_ move: MotionMove, number: Int, from source: Source) -> MotionLayer {
        let (layer, context) = (source.layer, source.context)
        let start = MoveExpansion.timing(of: move, in: context).start
        let color = move.color ?? colorOf(layer, at: start, context: context) ?? source.style.accent ?? source.style.text
        var random = SeededRandom(seed: seed("\(layer.id).burst\(number)"))
        let amount = move.intensity ?? 1
        let unit = context.unit
        let group = particlesID(of: layer.id, number: number)
        let pieces = (0..<particles).map { index -> MotionLayer in
            let angle = random.uniform(0...(2 * .pi))
            let distance = reach * context.canvas.height * amount * (0.3 + 0.7 * pow(random.unit(), 0.6))
            let side = random.uniform(sides) * unit
            let spin = random.uniform(120...480) * (random.unit() < 0.5 ? -1 : 1)
            let lasts = random.uniform(0.7...1.0) * duration
            var alpha = color
            alpha.alpha *= random.uniform(0.55...1)
            var piece = MotionLayer(
                id: "\(group).\(index)",
                content: .shape(ShapeContent(kind: .triangle, size: CGSize(width: side, height: side), color: alpha))
            )
            let thrown = MotionEasing.settle(timeConstant: 0.18)
            piece.keyframes = [
                .positionX: [Keyframe(time: start, value: 0, easing: thrown), Keyframe(time: start + lasts, value: cos(angle) * distance * reachAcross)],
                .positionY: [Keyframe(time: start, value: 0, easing: thrown), Keyframe(time: start + lasts, value: sin(angle) * distance)],
                .rotationZ: [Keyframe(time: start, value: random.uniform(0...360)), Keyframe(time: start + lasts, value: spin)],
                .scale: [Keyframe(time: start, value: 0.3, easing: .enterFast), Keyframe(time: start + 0.15, value: 1)],
                .opacity: [
                    Keyframe(time: start, value: 0), Keyframe(time: start + 0.04, value: 1),
                    Keyframe(time: start + lasts * 0.45, value: 1, easing: .exit), Keyframe(time: start + lasts, value: 0)
                ]
            ]
            return piece
        }
        let place = centre(of: layer, before: start, sizes: source.sizes, context: context)
        return MotionLayer(id: group, content: .group(pieces), transform: Transform3D(position: place))
    }

    // MARK: - Ripple

    private static func ripple(_ move: MotionMove, number: Int, from source: Source) -> MotionLayer {
        let (layer, context) = (source.layer, source.context)
        let start = MoveExpansion.timing(of: move, in: context).start
        let ringDuration = move.duration ?? rippleDuration
        let color = move.color ?? colorOf(layer, at: start, context: context) ?? source.style.accent ?? source.style.text
        let amount = move.intensity ?? 1
        let edge: (size: CGSize, radius: Double)
        if case .shape(let shape) = layer.content, !shape.isGlyph {
            // As its morphs have left it
            let state = ShapeMorph(shape, moves: layer.moves, context: context)?.state(at: start)
            edge = (state?.size ?? shape.size, state?.radius ?? shape.cornerRadius)
        } else {
            let side = 0.12 * context.canvas.height
            edge = (CGSize(width: side, height: side), side / 2)
        }
        let rings = (0..<rings).map { index -> MotionLayer in
            let begins = start + Double(index) * ringStagger
            let margin = ringReach * min(edge.size.width, edge.size.height) * amount * (1 + 0.4 * Double(index))
            // A thin ring by default, a pulse; soft bands that wide around anything but a rectangle, which has them inside
            let width = move.stroke ?? ringWidth * context.unit
            var ring = MotionLayer(
                id: "\(layer.id).ripple\(number).\(index)",
                content: .shape(ShapeContent(size: edge.size, cornerRadius: edge.radius, color: color, stroke: width))
            )
            ring.blur = move.stroke == nil ? 0 : width * softBands
            var opening = MotionMove(.morph, start: begins, duration: ringDuration)
            opening.size = CGSize(width: edge.size.width + 2 * margin, height: edge.size.height + 2 * margin)
            ring.moves = [opening]
            ring.keyframes[.opacity] = [
                Keyframe(time: begins, value: 0), Keyframe(time: begins + 0.06, value: 0.85, easing: .exit), Keyframe(time: begins + ringDuration, value: 0)
            ]
            return ring
        }
        let place = centre(of: layer, before: start, sizes: source.sizes, context: context)
        return MotionLayer(id: "\(layer.id).ripple\(number)", content: .group(rings), transform: Transform3D(position: place))
    }

    // MARK: - Where they come from

    /// The middle of `layer` where its morphs and scrolls have taken it by `time`, in its parent's space.
    private static func centre(of layer: MotionLayer, before time: Double, sizes: [String: CGSize], context: MoveContext) -> SIMD3<Double> {
        let travels = layer.moves.filter { [.morph, .scroll].contains($0.kind) && $0.target != nil }
            .map { (target: $0.target, start: MoveExpansion.timing(of: $0, in: context).start) }
            .filter { $0.start <= time }
            .sorted { $0.start < $1.start }
        let place = travels.last?.target ?? CGPoint(x: layer.transform.position.x, y: layer.transform.position.y)
        let size: CGSize = if case .text(let text) = layer.content { TextImage(text, scale: 0).size } else { MotionPlan.size(of: layer.content, sizes: sizes) }
        let anchor = layer.transform.anchor
        let scale = layer.transform.scale
        return [place.x + (0.5 - anchor.x) * size.width * scale, place.y + (0.5 - anchor.y) * size.height * scale, layer.transform.position.z]
    }

    /// A shape's colour once its morphs have changed it by `time`, unless it's mostly clear: a disc that turns green
    /// as it bursts throws green, not the faint white it was.
    private static func colorOf(_ layer: MotionLayer, at time: Double, context: MoveContext) -> RGBAColor? {
        guard case .shape(let shape) = layer.content else { return nil }
        let color = layer.moves.filter { $0.kind == .morph && $0.color != nil && MoveExpansion.timing(of: $0, in: context).start <= time }
            .max { MoveExpansion.timing(of: $0, in: context).start < MoveExpansion.timing(of: $1, in: context).start }?.color ?? shape.color
        return color.alpha >= 0.5 ? color : nil
    }

    /// FNV-1a of `text`: the same particles for the same layer on every launch.
    private static func seed(_ text: String) -> UInt64 {
        text.utf8.reduce(0xCBF2_9CE4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01B3 }
    }
}
