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

    /// A soft band of light opening inside the shape from its middle to its edge: a ripple with a stroke, the flood's.
    nonisolated struct Band: Sendable {
        let start: Double
        let duration: Double
        let color: RGBAColor
        let width: Double
    }

    /// The film's flood (measured at 30 fps): a dip to 0.57 of its size in 0.17 s, then a rounded rectangle of about the
    /// frame's shape, its corners round to 0.35 of its height, that covers the frame 0.3 s on and stops just past its
    /// corners at 0.4 s, out-cubic. Grown as the pill was, round, it had to reach 3–4 frame widths to cover the corners and
    /// filled the frame in two frames.
    static let floodDip = 0.17
    static let floodFill = 0.4
    static let floodDipScale = 0.57
    static let floodRoundness = 0.35
    static let floodPast = 1.05

    let base: State
    let steps: [Step]
    let bands: [Band]

    /// Whether `move` on `shape` opens soft bands inside it rather than rings around it.
    static func isBand(_ move: MotionMove, on shape: ShapeContent) -> Bool {
        move.kind == .ripple && move.stroke != nil && !shape.isGlyph
    }

    /// `shape` changed by `moves` in the order they start; `nil` when none changes it.
    init?(_ shape: ShapeContent, moves: [MotionMove], context: MoveContext) {
        let changes = moves.filter { [.morph, .flood].contains($0.kind) }
            .map { (move: $0, timing: MoveExpansion.timing(of: $0, in: context)) }
            .sorted { $0.timing.start < $1.timing.start }
        let bands = moves.filter { Self.isBand($0, on: shape) }.map { move in
            let timing = MoveExpansion.timing(of: move, in: context)
            return Band(start: timing.start, duration: timing.duration, color: move.color ?? shape.color, width: move.stroke ?? 0)
        }
        guard !shape.isGlyph, !bands.isEmpty || changes.contains(where: { change in
            let move = change.move
            return move.kind == .flood || move.size != nil || move.radius != nil || move.color != nil || move.stroke != nil
        }) else { return nil }
        base = State(size: shape.size, radius: min(shape.cornerRadius, min(shape.size.width, shape.size.height) / 2), color: shape.color, stroke: shape.stroke ?? 0)
        self.bands = bands
        var steps: [Step] = []
        var state = base
        var place = context.position
        for (move, timing) in changes {
            defer { place = move.target ?? place }
            if move.kind == .flood {
                let share = Self.floodDip / (Self.floodDip + Self.floodFill)
                let dip = Self.resized(state, to: CGSize(width: state.size.width * Self.floodDipScale, height: state.size.height * Self.floodDipScale))
                var filled = state
                filled.size = Self.floodSize(from: place, canvas: context.canvas)
                filled.radius = Self.floodRoundness * filled.size.height
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
        guard !steps.isEmpty || !bands.isEmpty else { return nil }
        self.steps = steps
    }

    /// `state` at another size: round corners stay round, others keep their radius as far as it fits.
    private static func resized(_ state: State, to size: CGSize) -> State {
        var resized = state
        resized.size = size
        resized.radius = state.isRound ? resized.half : min(state.radius, resized.half)
        return resized
    }

    /// The flood's size: the frame's shape, its corners ``floodRoundness`` of its height round, ``floodPast`` the size that
    /// covers the frame from `centre` (canvas pixels).
    private static func floodSize(from centre: CGPoint, canvas: CGSize) -> CGSize {
        let middle = CGPoint(x: min(max(centre.x, 0), canvas.width), y: min(max(centre.y, 0), canvas.height))
        let corners = [CGPoint.zero, CGPoint(x: canvas.width, y: 0), CGPoint(x: 0, y: canvas.height), CGPoint(x: canvas.width, y: canvas.height)]
        // Half the frame's size each way is the frame itself
        var factor = 0.5
        while factor < 8 {
            let half = CGSize(width: canvas.width * factor, height: canvas.height * factor)
            let radius = floodRoundness * 2 * half.height
            let covers = corners.allSatisfy { corner in
                // How far the frame's corner is past where the shape's rounded corner starts
                let past = CGPoint(x: abs(corner.x - middle.x) - (half.width - radius), y: abs(corner.y - middle.y) - (half.height - radius))
                return past.x <= 0 || past.y <= 0 ? abs(corner.x - middle.x) <= half.width && abs(corner.y - middle.y) <= half.height
                    : hypot(past.x, past.y) <= radius
            }
            if covers {
                return CGSize(width: 2 * half.width * floodPast, height: 2 * half.height * floodPast)
            }
            factor *= 1.01
        }
        return CGSize(width: canvas.width * 16, height: canvas.height * 16)
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
        let state = state(at: time)
        let shape = Self.image(of: state, scale: scale)
        return bands.filter { time > $0.start && time < $0.start + $0.duration }.reduce(shape) { image, band in
            // Clipped to the shape, so the bands go where the shape goes, an iris too
            Self.image(of: band, at: time, in: state, scale: scale)
                .applyingFilter("CISourceAtopCompositing", parameters: [kCIInputBackgroundImageKey: image])
                .cropped(to: shape.extent)
        }
    }

    /// `band` at `time` inside a shape in `state`: an outline of its shape from a tenth of its size out past its edge,
    /// blurred to ``BurstExpansion/softBands`` of its width, at most 0.85 opaque and fading as it opens.
    private static func image(of band: Band, at time: Double, in state: State, scale: Double) -> CIImage {
        let fraction = (time - band.start) / band.duration
        let factor = 0.1 + 0.95 * MotionEasing.enter.progress(fraction, duration: band.duration)
        var ring = State(size: CGSize(width: state.size.width * factor, height: state.size.height * factor), radius: state.radius * factor, color: band.color,
                         stroke: band.width)
        ring.stroke = min(ring.stroke, ring.half)
        let opacity = 0.85 * min((time - band.start) / 0.06, 1) * (1 - MotionEasing.exit.progress(fraction, duration: band.duration))
        let offset = CGAffineTransform(
            translationX: ((state.size.width - ring.size.width) * scale / 2).rounded(), y: ((state.size.height - ring.size.height) * scale / 2).rounded()
        )
        return image(of: ring, scale: scale).transformed(by: offset)
            .applyingGaussianBlur(sigma: band.width * BurstExpansion.softBands * scale).fading(to: opacity)
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
