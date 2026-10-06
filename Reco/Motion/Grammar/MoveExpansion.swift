//
//  MoveExpansion.swift
//  Reco
//

import CoreGraphics
import Foundation

/// What a move does to the layer or camera it's on, at the times it resolves to.
nonisolated struct MoveEffect: Sendable {

    /// Changes to properties: a factor of the base for ``MotionProperty/isFactor`` properties, an
    /// amount added to it otherwise.
    var tracks: [MotionProperty: [PropertyTrack]] = [:]

    var reveal: TextReveal?

    /// The part a focus keeps lit, in fractions of the layer.
    var region: CGRect?
}

/// Where a move happens: its scene, and the layer or camera it moves.
nonisolated struct MoveContext: Sendable {
    let sceneDuration: Double
    let canvas: CGSize

    /// Where the camera looks before its moves; only pans use it.
    var lookAt = CGPoint.zero

    /// A text layer's characters and lines; 0 for any other layer.
    var characters = 0
    var lines = 0

    /// Canvas pixels per pixel of a 1080p canvas: the grammar's distances are measured at 1080p.
    var unit: Double {
        canvas.height / 1080
    }
}

/// The grammar's moves as tracks: the only place a move's timing, distance and easing are decided
/// (spec 0011, *Craft defaults*; measured values in *Measured references*).
nonisolated enum MoveExpansion {

    /// The first move starts this long after its seam: 0.1–0.3 s (HyperFrames); never at 0, a tell.
    static let entranceStart = 0.2

    /// A drift runs this long past its scene, so a push or a fade into the next scene still sees it moving.
    static let driftOverrun = 1.0

    /// Linear's camera drifts ~2% of the width a second (0.4–3.5) and pushes in slowly.
    static let driftSpeed = 0.02
    static let driftZoom = 0.01

    /// Typing: 15 characters a second (7.5–25 measured).
    static let typingRate = 15.0

    /// Peak pan speed: 57% of the width a second (median of the reference films, 13–113).
    static let panSpeed = 0.57

    static func timing(of move: MotionMove, in context: MoveContext) -> (start: Double, duration: Double) {
        let start = move.start ?? defaultStart(of: move.kind, in: context)
        return (start, move.duration ?? defaultDuration(of: move, start: start, in: context))
    }

    static func effect(of move: MotionMove, in context: MoveContext) -> MoveEffect { // swiftlint:disable:this cyclomatic_complexity
        let (start, duration) = timing(of: move, in: context)
        if move.kind.isCamera {
            return MoveEffect(tracks: cameraTracks(of: move, start: start, duration: duration, in: context))
        }
        let amount = move.intensity ?? 1
        let unit = context.unit
        var effect = MoveEffect()
        func add(_ property: MotionProperty, _ begin: Double, _ end: Double, easing: MotionEasing) {
            effect.tracks[property, default: []].append(ramp(property, (begin, end), start: start, duration: duration, easing: easing))
        }
        switch move.kind {
        case .fadeUp:
            add(.opacity, 0, 1, easing: .enter)
            add(.positionY, 16 * unit * amount, 0, easing: .enter)
        case .blurIn:
            add(.opacity, 0, 1, easing: .enter)
            // At most 10 px on text (HyperFrames' cut catalogue)
            add(.blur, 10 * unit * amount, 0, easing: .enter)
        case .exit:
            add(.opacity, 1, 0, easing: .exit)
            add(.positionY, 0, -8 * unit * amount, easing: .exit)
            add(.blur, 0, 6 * unit * amount, easing: .exit)
        case .roll, .cascade, .hold, .push, .pullBack, .drift, .pan:
            // A roll and a cascade become other layers' moves (``DocumentExpansion``)
            break
        case .blurWipe, .lineMask, .type:
            effect.reveal = reveal(move, start: start, duration: duration, in: context)
        case .rise:
            add(.opacity, 0, 1, easing: .cascade)
            // From 0.9–0.97 and at most 16 px (agentic-product-demo)
            add(.scale, 1 - 0.04 * amount, 1, easing: .cascade)
            add(.positionY, 16 * unit * amount, 0, easing: .cascade)
        case .tilt:
            add(.rotationX, 0, 18 * amount, easing: .move)
        case .focus:
            add(.dim, 0, min(0.55 * amount, 1), easing: .move)
            effect.region = move.region
        case .detach:
            add(.positionZ, 0, -80 * unit * amount, easing: .move)
            add(.scale, 1, 1 + 0.03 * amount, easing: .move)
            add(.shadow, 0.35, 1, easing: .move)
        case .stateChange:
            add(.opacity, 0, 1, easing: .enterFast)
            add(.blur, 4 * unit * amount, 0, easing: .enterFast)
        }
        return effect
    }

    /// A camera move's tracks; a hold has none.
    private static func cameraTracks(of move: MotionMove, start: Double, duration: Double, in context: MoveContext) -> [MotionProperty: [PropertyTrack]] {
        let amount = move.intensity ?? 1
        switch move.kind {
        case .push:
            return [.scale: [ramp(.scale, (1, 1 + 0.12 * amount), start: start, duration: duration, easing: .move)]]
        case .pullBack:
            return [.scale: [ramp(.scale, (1 + 0.3 * amount, 1), start: start, duration: duration, easing: .longSettle)]]
        case .drift:
            // Constant speed: a steady pan and a slow push, in log space
            let travel = driftDirection(move.direction) * driftSpeed * amount * context.canvas.width * duration
            return [
                .positionX: [ramp(.positionX, (0, travel.x), start: start, duration: duration, easing: .linear)],
                .positionY: [ramp(.positionY, (0, travel.y), start: start, duration: duration, easing: .linear)],
                .scale: [ramp(.scale, (1, pow(1 + driftZoom * amount, duration)), start: start, duration: duration, easing: .linear)]
            ]
        case .pan:
            return pan(to: move.target ?? context.lookAt, zoom: amount, start: start, duration: duration, in: context)
        default:
            return [:]
        }
    }

    /// From `begin` at `start` to `end` `duration` later.
    private static func ramp(_ property: MotionProperty, _ values: (begin: Double, end: Double), start: Double, duration: Double, easing: MotionEasing) -> PropertyTrack {
        PropertyTrack(property, from: Keyframe(time: start, value: values.begin, easing: easing), to: Keyframe(time: start + duration, value: values.end))
    }

    private static func defaultStart(of kind: MotionMove.Kind, in context: MoveContext) -> Double {
        switch kind {
        case .exit: max(context.sceneDuration - defaultDuration(of: MotionMove(.exit), start: 0, in: context), 0)
        case .pullBack, .drift, .hold: 0
        default: entranceStart
        }
    }

    private static func defaultDuration(of move: MotionMove, start: Double, in context: MoveContext) -> Double { // swiftlint:disable:this cyclomatic_complexity
        let rest = max(context.sceneDuration - start, 1 / 60)
        switch move.kind {
        case .fadeUp: return 0.45
        // Titles blur in over 0.5–0.63 s
        case .blurIn: return 0.55
        // Shorter than what entered (0.25 against 0.4 s)
        case .exit: return 0.25
        // ~44 ms a character (Linear), each sharpening over 0.3 s
        case .blurWipe: return 0.044 * Double(max(context.characters - 1, 0)) + 0.3
        case .lineMask: return 0.12 * Double(max(context.lines - 1, 0)) + 0.6
        case .type: return Double(context.characters) / typingRate
        // A roll every ~0.5 s
        case .roll: return 0.5 * Double(move.words?.count ?? 1)
        case .rise: return 0.6
        case .tilt: return 1.2
        case .focus, .detach: return 0.6
        case .stateChange: return 0.2
        // Rows 2–2.5 frames apart at 30 fps, each over 30–33 frames, the group within 0.5 s
        case .cascade: return 1.05
        case .push: return min(1.2, rest)
        case .pan: return panDuration(to: move.target ?? context.lookAt, zoom: move.intensity ?? 1, in: context)
        case .pullBack, .hold: return rest
        case .drift: return rest + driftOverrun
        }
    }

    private static func reveal(_ move: MotionMove, start: Double, duration: Double, in context: MoveContext) -> TextReveal {
        let characters = Double(max(context.characters, 1))
        switch move.kind {
        case .type:
            return TextReveal(style: .type, start: start, stagger: duration / characters, partDuration: 0)
        case .lineMask:
            let part = min(0.6, duration)
            return TextReveal(style: .rise, start: start, stagger: (duration - part) / Double(max(context.lines - 1, 1)), partDuration: part)
        default:
            let part = min(0.3, duration)
            return TextReveal(style: .wipe, start: start, stagger: (duration - part) / max(characters - 1, 1), partDuration: part)
        }
    }

    private static func driftDirection(_ direction: MotionMove.Direction?) -> SIMD2<Double> {
        switch direction ?? .right {
        case .left: [-1, 0]
        case .right: [1, 0]
        case .upward: [0, -1]
        case .downward: [0, 1]
        }
    }

    /// Long enough that the pan's fastest moment stays at ``panSpeed`` (a zoom counted as the
    /// distance its view's edge travels), and at least 0.5 s.
    private static func panDuration(to target: CGPoint, zoom: Double, in context: MoveContext) -> Double {
        let distance = hypot(target.x - context.lookAt.x, target.y - context.lookAt.y) + abs(1 - 1 / zoom) * context.canvas.width / 2
        return max(0.5, steepestMove * distance / (panSpeed * context.canvas.width))
    }

    /// The move easing's steepest slope: its peak speed over its average.
    private static let steepestMove: Double = {
        let samples = 400
        return (1...samples).map { index in
            let (before, after) = (Double(index - 1) / Double(samples), Double(index) / Double(samples))
            return (MotionEasing.move.progress(after, duration: 1) - MotionEasing.move.progress(before, duration: 1)) * Double(samples)
        }.max() ?? 1
    }()

    /// The camera's look-at offset and zoom along the ``ZoomPath`` to `target` seen `zoom` times
    /// closer, eased with ``MotionEasing/move`` and sampled at 30 Hz.
    private static func pan(to target: CGPoint, zoom: Double, start: Double, duration: Double, in context: MoveContext) -> [MotionProperty: [PropertyTrack]] {
        let path = ZoomPath(from: context.lookAt, width: context.canvas.width, to: target, width: context.canvas.width / zoom)
        let count = max(Int((duration * 30).rounded(.up)), 1)
        var keyframes: [MotionProperty: [Keyframe]] = [:]
        for index in 0...count {
            let fraction = Double(index) / Double(count)
            let view = path.view(at: MotionEasing.move.progress(fraction, duration: duration))
            let time = start + fraction * duration
            keyframes[.positionX, default: []].append(Keyframe(time: time, value: view.center.x - context.lookAt.x))
            keyframes[.positionY, default: []].append(Keyframe(time: time, value: view.center.y - context.lookAt.y))
            keyframes[.scale, default: []].append(Keyframe(time: time, value: context.canvas.width / view.width))
        }
        return keyframes.reduce(into: [:]) { tracks, entry in
            tracks[entry.key] = PropertyTrack(entry.key, keyframes: entry.value).map { [$0] }
        }
    }
}
