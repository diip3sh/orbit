//
//  ShapeMorph.swift
//  Reco
//

import CoreGraphics
import CoreImage

/// A rectangle's shape over time as its morphs and floods leave it (spec 0014): one object that changes state, as
/// motion design's pill grows out of a dot, floods the frame, drains to an outline and shrinks to a caret. Each
/// change starts from where the one before left it, so a document names only where each goes.
nonisolated struct ShapeMorph: Sendable {

    nonisolated struct State: Equatable, Sendable {
        var size: CGSize
        var radius: Double
        var color: RGBAColor

        /// An outline this wide; 0 is filled.
        var stroke: Double

        /// Its outline's width, the fill counted as an outline half its shorter side wide, so an outline thickens
        /// into a fill.
        var outline: Double {
            stroke > 0 ? min(stroke, half) : half
        }

        var half: Double {
            min(size.width, size.height) / 2
        }

        /// Whether its corners are as round as they go: a pill or a disc stays one as it changes size.
        var isRound: Bool {
            radius >= half - 0.5
        }
    }

    nonisolated struct Step: Sendable {
        let start: Double
        let duration: Double
        let easing: MotionEasing
        let before: State
        let after: State
    }

    /// The film's flood: a dip to 0.6 of its size in 0.17 s, then past the frame's corners in 0.4 s, out-cubic.
    static let floodDip = 0.17
    static let floodFill = 0.4
    static let floodDipScale = 0.6

    let base: State
    let steps: [Step]

    /// `shape` changed by `moves` in the order they start; `nil` when none changes it.
    init?(_ shape: ShapeContent, moves: [MotionMove], context: MoveContext) {
        let changes = moves.filter { [.morph, .flood].contains($0.kind) }
            .map { (move: $0, timing: MoveExpansion.timing(of: $0, in: context)) }
            .sorted { $0.timing.start < $1.timing.start }
        guard !shape.isGlyph, changes.contains(where: { change in
            let move = change.move
            return move.kind == .flood || move.size != nil || move.radius != nil || move.color != nil || move.stroke != nil
        }) else { return nil }
        base = State(size: shape.size, radius: min(shape.cornerRadius, min(shape.size.width, shape.size.height) / 2), color: shape.color, stroke: shape.stroke ?? 0)
        var steps: [Step] = []
        var state = base
        for (move, timing) in changes {
            if move.kind == .flood {
                let share = Self.floodDip / (Self.floodDip + Self.floodFill)
                let dip = Self.resized(state, to: CGSize(width: state.size.width * Self.floodDipScale, height: state.size.height * Self.floodDipScale))
                var filled = Self.resized(state, to: Self.floodSize(of: state, canvas: context.canvas))
                filled.stroke = 0
                steps.append(Step(start: timing.start, duration: timing.duration * share, easing: .enter, before: state, after: dip))
                steps.append(Step(start: timing.start + timing.duration * share, duration: timing.duration * (1 - share), easing: .enter, before: dip, after: filled))
                state = filled
                continue
            }
            var next = move.size.map { Self.resized(state, to: $0) } ?? state
            next.radius = move.radius.map { min($0, next.half) } ?? next.radius
            next.color = move.color ?? next.color
            next.stroke = move.stroke ?? next.stroke
            guard next != state else { continue }
            steps.append(Step(start: timing.start, duration: timing.duration, easing: .morph, before: state, after: next))
            state = next
        }
        guard !steps.isEmpty else { return nil }
        self.steps = steps
    }

    /// `state` at another size: round corners stay round, others keep their radius as far as it fits.
    private static func resized(_ state: State, to size: CGSize) -> State {
        var resized = state
        resized.size = size
        resized.radius = state.isRound ? resized.half : min(state.radius, resized.half)
        return resized
    }

    /// Large enough, round as it is, to cover the frame from anywhere on it: its middle can be at any corner.
    private static func floodSize(of state: State, canvas: CGSize) -> CGSize {
        var factor = 1.0
        let aspect = state.size.width / max(state.size.height, 1e-6)
        let roundness = state.radius / max(state.half, 1e-6)
        for _ in 0..<64 {
            let height = max(canvas.height * 2, canvas.width * 2 / aspect) * factor
            let size = CGSize(width: height * aspect, height: height)
            let radius = roundness * min(size.width, size.height) / 2
            // The far corner of the frame, from the shape's middle at the near one, inside its rounded corner
            let inner = CGPoint(x: size.width / 2 - radius, y: size.height / 2 - radius)
            let corner = CGPoint(x: max(canvas.width - inner.x, 0), y: max(canvas.height - inner.y, 0))
            if hypot(corner.x, corner.y) <= radius {
                return size
            }
            factor *= 1.15
        }
        return CGSize(width: canvas.width * 8, height: canvas.height * 8)
    }

    /// The shape at `time` in its scene.
    func state(at time: Double) -> State {
        guard let index = steps.lastIndex(where: { $0.start <= time }) else { return base }
        let step = steps[index]
        guard step.duration > 0, time < step.start + step.duration else { return step.after }
        let progress = step.easing.progress((time - step.start) / step.duration, duration: step.duration)
        return Self.interpolated(step.before, step.after, progress)
    }

    private static func interpolated(_ before: State, _ after: State, _ progress: Double) -> State {
        let mix = { (first: Double, second: Double) in first + (second - first) * progress }
        let size = CGSize(width: max(mix(before.size.width, after.size.width), 0), height: max(mix(before.size.height, after.size.height), 0))
        // Colour mixed premultiplied, so a fill coming from clear doesn't pass through black
        let alpha = mix(before.color.alpha, after.color.alpha)
        let channel = { (first: Double, second: Double) in alpha > 0 ? mix(first * before.color.alpha, second * after.color.alpha) / alpha : second }
        let color = RGBAColor(red: channel(before.color.red, after.color.red), green: channel(before.color.green, after.color.green),
                              blue: channel(before.color.blue, after.color.blue), alpha: min(max(alpha, 0), 1))
        var state = State(size: size, radius: 0, color: color, stroke: 0)
        state.radius = before.isRound && after.isRound ? state.half : min(max(mix(before.radius, after.radius), 0), state.half)
        let outline = mix(before.outline, after.outline)
        state.stroke = outline >= state.half - 0.01 ? 0 : max(outline, 0)
        return state
    }

    /// The shape at `time` at `scale` pixels per canvas pixel, over its whole box in whole pixels, as every layer
    /// image is (`CIPerspectiveTransform` maps an image's extent to its quad).
    func image(at time: Double, scale: Double) -> CIImage {
        Self.image(of: state(at: time), scale: scale)
    }

    static func image(of state: State, scale: Double) -> CIImage {
        let box = CGRect(x: 0, y: 0, width: max((state.size.width * scale).rounded(), 1), height: max((state.size.height * scale).rounded(), 1))
        let color = CIColor(red: state.color.red, green: state.color.green, blue: state.color.blue, alpha: state.color.alpha)
        let shape: CIImage?
        if state.stroke > 0 {
            // The generator draws the line inside the extent: measured, a 3 px line over the box's first three rows
            shape = CIFilter(name: "CIRoundedRectangleStrokeGenerator", parameters: [
                "inputExtent": CIVector(cgRect: box), "inputRadius": state.radius * scale, "inputColor": color, "inputWidth": state.stroke * scale
            ])?.outputImage
        } else {
            shape = CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
                "inputExtent": CIVector(cgRect: box), "inputRadius": state.radius * scale, "inputColor": color
            ])?.outputImage
        }
        return (shape ?? .empty()).composited(over: CIImage(color: .clear).cropped(to: box)).cropped(to: box)
    }
}
