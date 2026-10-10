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

    /// Where the camera looks before the move, and how much closer than at the scene's start; only pans and whips use them.
    var lookAt = CGPoint.zero
    var zoom = 1.0

    /// Where the layer's anchor sits before its moves; only a scroll's length uses it.
    var position = CGPoint.zero

    /// A text layer's characters, words and lines; 0 for any other layer.
    var characters = 0
    var words = 0
    var lines = 0

    /// Counts `text`'s parts, for the reveals that time themselves by them.
    mutating func measure(_ text: TextImage) {
        (characters, words, lines) = (text.characters.count, text.words.count, text.lines.count)
    }

    /// Canvas pixels per pixel of a 1080p canvas: the grammar's distances are measured at 1080p.
    var unit: Double {
        canvas.height / 1080
    }
}

nonisolated extension MoveContext {

    /// The context of `layer`'s moves, its text counted.
    init(sceneDuration: Double, canvas: CGSize, layer: MotionLayer) {
        self.init(sceneDuration: sceneDuration, canvas: canvas)
        position = CGPoint(x: layer.transform.position.x, y: layer.transform.position.y)
        if case .text(let text) = layer.content {
            measure(TextImage(text, scale: 0))
        }
    }
}

/// The grammar's moves as tracks: the only place a move's timing, distance and easing are decided
/// (spec 0011, *Craft defaults*; measured values in *Measured references*).
nonisolated enum MoveExpansion {

    /// The first move starts this long after its seam: 0.1–0.3 s (HyperFrames); never at 0, a tell.
    /// At 0.2 s, with UI fading in over its whole rise, a Linear film cut every 2 s showed bare ground
    /// for the first 0.3–0.8 s of each shot (2026-10-07).
    static let entranceStart = 0.1

    /// UI coming in is there almost at once and settles as it moves: the cut is the transition.
    static let uiAppearance = 0.15

    /// A drift runs this long past its scene, so a push or a fade into the next scene still sees it moving.
    static let driftOverrun = 1.0

    /// Linear's camera drifts ~2% of the width a second (0.4–3.5) and pushes in slowly.
    static let driftSpeed = 0.02
    static let driftZoom = 0.01

    /// The farthest a drift pans over its scene, as a share of the width; its zoom slows with it.
    /// At 2% and 1% a second, a 10 s scene slid its captions at the margin (8% of the width) off the
    /// frame, the zoom (12% by its end) more than the pan.
    static let longestDrift = 0.04

    /// How far a slide in or a sideways exit travels, in pixels at 1080p.
    static let slideDistance = 72.0

    /// Typing: 15 characters a second (7.5–25 measured).
    static let typingRate = 15.0

    /// Peak pan speed: 57% of the width a second (median of the reference films, 13–113).
    static let panSpeed = 0.57

    /// How much closer a push ends, and a pull back starts, at intensity 1.
    static let pushZoom = 0.12
    static let pullBackZoom = 0.3

    /// A whip: the approved film's camera to its code block, 0.35 s on a steep in-out, blurred by the
    /// motion blur sampled across it.
    static let whipDuration = 0.35

    // MARK: Motion design (spec 0014), measured on LordyVisuals' Spotify Jam film

    /// A morph: the film's pill growing out of a dot in 0.43 s.
    static let morphDuration = 0.43

    /// Letters 0.036 s apart ("Start a Jam", 11 in 0.4 s), each in over 0.4 s (``TextReveal/letterPose(_:)``).
    static let letterStagger = 0.036
    static let letterDuration = 0.4

    /// Kinetic typing: "Black & Tan" at about 13 characters a second.
    static let kineticRate = 13.0

    /// A pop grows from 0.6 of its size, past it and back, in 0.4 s; a press dips to 0.92 in 0.1 s and springs back.
    static let popFrom = 0.6
    static let popDuration = 0.4
    static let pressDepth = 0.92
    static let pressDown = 0.1
    static let pressDuration = 0.4

    /// A spin turns a quarter turn into place, overshooting, in 0.5 s: the film's "+" spinning in (11.7–12.3 s).
    static let spinTurn = 90.0
    static let spinDuration = 0.5

    /// A scroll's fastest moment in canvas heights a second: the film's queue went 1.83 heights in 1.5 s, in and out.
    static let scrollSpeed = 1.8

    static func timing(of move: MotionMove, in context: MoveContext) -> (start: Double, duration: Double) {
        let start = move.start ?? defaultStart(of: move.kind, in: context)
        return (start, move.duration ?? defaultDuration(of: move, start: start, in: context))
    }

    static func effect(of move: MotionMove, in context: MoveContext) -> MoveEffect { // swiftlint:disable:this cyclomatic_complexity
        let (start, duration) = timing(of: move, in: context)
        if move.kind.isCamera {
            return MoveEffect(tracks: cameraTracks(of: move, start: start, duration: duration, in: context))
        }
        guard !MotionMove.Kind.storyKinds.contains(move.kind) else { return MoveEffect(tracks: storyTracks(of: move, start: start, duration: duration, in: context)) }
        let (amount, unit) = (move.intensity ?? 1, context.unit)
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
            effect.tracks = exitTracks(of: move, start: start, duration: duration, in: context)
        case .roll, .cascade, .hold, .push, .pullBack, .drift, .pan, .whip, .burst, .ripple, .morph, .flood, .scroll, .shimmer, .wash, .show, .hide, .scatter, .select, .fly:
            // A roll, a cascade, a burst and a ripple become other layers' moves (``DocumentExpansion``); a morph, a
            // flood and a scroll a shape's states and the layer's place, with the others before and after (``ShapeMorph``);
            // a story's moves are expanded above; a selection is drawn behind the text (``TextSelection``)
            break
        case .blurWipe, .lineMask, .wordByWord, .type, .letters, .kinetic, .voice, .reply:
            effect.reveal = reveal(move, start: start, duration: duration, in: context)
        case .pop:
            effect.tracks[.opacity] = [ramp(.opacity, (0, 1), start: start, duration: min(0.1, duration), easing: .enterFast)]
            add(.scale, 1 - (1 - popFrom) * min(amount, 1.5), 1, easing: .overshoot)
        case .press, .click:
            effect.tracks[.scale] = pressTracks(depth: pow(pressDepth, amount), start: start, duration: duration)
        case .spin:
            add(.rotationZ, -spinTurn * amount, 0, easing: .overshoot)
        case .rise:
            effect.tracks[.opacity] = [ramp(.opacity, (0, 1), start: start, duration: min(uiAppearance, duration), easing: .enterFast)]
            // From 0.9–0.97 and at most 16 px (agentic-product-demo)
            add(.scale, 1 - 0.04 * amount, 1, easing: .cascade)
            add(.positionY, 16 * unit * amount, 0, easing: .cascade)
        case .slideIn:
            effect.tracks = slideTracks(of: move, start: start, duration: duration, in: context)
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

    /// The context each of a scene's camera `moves` starts from, in their order: where the moves that start before it left the
    /// camera. A macro's whips go from stop to stop; a pan back out follows a pan in.
    static func cameraContexts(of moves: [MotionMove], from context: MoveContext) -> [MoveContext] {
        let order = moves.indices.sorted { (timing(of: moves[$0], in: context).start, $0) < (timing(of: moves[$1], in: context).start, $1) }
        var contexts = Array(repeating: context, count: moves.count)
        var camera = context
        for index in order {
            contexts[index] = camera
            let move = moves[index]
            let amount = move.intensity ?? 1
            switch move.kind {
            case .whip:
                camera.lookAt = move.target ?? camera.lookAt
                camera.zoom *= amount
            case .pan:
                camera.lookAt = move.target ?? camera.lookAt
                camera.zoom = amount
            case .push:
                camera.zoom *= 1 + pushZoom * amount
            default:
                break
            }
        }
        return contexts
    }

    /// Where morphs and scrolls with `to` take a layer from `position`, as changes added to its place: each from
    /// where the one before left it, so a document names only where it goes.
    static func placeTracks(of moves: [MotionMove], from position: CGPoint, in context: MoveContext) -> [MotionProperty: [PropertyTrack]] {
        let travels = moves.filter { [.morph, .scroll].contains($0.kind) && $0.target != nil }
            .map { (move: $0, start: timing(of: $0, in: context).start) }
            .sorted { $0.start < $1.start }
        var tracks: [MotionProperty: [PropertyTrack]] = [:]
        var place = position
        for (move, start) in travels {
            guard let target = move.target else { continue }
            var from = context
            from.position = place
            let duration = timing(of: move, in: from).duration
            let easing: MotionEasing = move.kind == .scroll ? .scroll : .morph
            for (property, change) in [(MotionProperty.positionX, target.x - place.x), (.positionY, target.y - place.y)] where change != 0 {
                tracks[property, default: []].append(ramp(property, (0, change), start: start, duration: duration, easing: easing))
            }
            place = target
        }
        return tracks
    }

    /// Down to `depth` of its size and springing back past it: a press, which a click's pointer makes too.
    private static func pressTracks(depth: Double, start: Double, duration: Double) -> [PropertyTrack] {
        let down = min(pressDown, duration / 2)
        return [
            ramp(.scale, (1, depth), start: start, duration: down, easing: .enter),
            ramp(.scale, (1, 1 / depth), start: start + down, duration: duration - down, easing: .overshoot)
        ]
    }

    /// An exit: it fades, rising a little and blurring; or with a direction, it goes that way, blurred
    /// as fast motion is, as the next one comes in.
    private static func exitTracks(of move: MotionMove, start: Double, duration: Double, in context: MoveContext) -> [MotionProperty: [PropertyTrack]] {
        let amount = (move.intensity ?? 1) * context.unit
        let way = move.direction.map { slideDirection($0) * slideDistance } ?? [0, -8]
        let ramps: [MotionProperty: (begin: Double, end: Double)] = [
            .opacity: (1, 0), .positionX: (0, way.x * amount), .positionY: (0, way.y * amount), .blur: (0, (move.direction == nil ? 6 : 10) * amount)
        ]
        return ramps.reduce(into: [:]) { tracks, entry in
            tracks[entry.key] = [ramp(entry.key, entry.value, start: start, duration: duration, easing: .exit)]
        }
    }

    /// A slide in from the side it moves away from, sharpening and turning a little towards its rest:
    /// fast, then a long settle, so it keeps moving for as long as it's shown.
    private static func slideTracks(of move: MotionMove, start: Double, duration: Double, in context: MoveContext) -> [MotionProperty: [PropertyTrack]] {
        let amount = move.intensity ?? 1
        let way = slideDirection(move.direction ?? .left) * slideDistance * context.unit * amount
        let turn = way.x == 0 ? 0 : 8 * amount * (way.x > 0 ? -1 : 1)
        return [
            .positionX: [ramp(.positionX, (-way.x, 0), start: start, duration: duration, easing: .longSettle)],
            .positionY: [ramp(.positionY, (-way.y, 0), start: start, duration: duration, easing: .longSettle)],
            .rotationY: [ramp(.rotationY, (turn, 0), start: start, duration: duration, easing: .longSettle)],
            .opacity: [ramp(.opacity, (0, 1), start: start, duration: min(uiAppearance, duration), easing: .enterFast)],
            .blur: [ramp(.blur, (14 * context.unit * amount, 0), start: start, duration: min(0.4, duration), easing: .enter)]
        ]
    }

    /// A camera move's tracks; a hold has none.
    private static func cameraTracks(of move: MotionMove, start: Double, duration: Double, in context: MoveContext) -> [MotionProperty: [PropertyTrack]] {
        let amount = move.intensity ?? 1
        switch move.kind {
        case .push:
            return [.scale: [ramp(.scale, (1, 1 + pushZoom * amount), start: start, duration: duration, easing: .move)]]
        case .pullBack:
            return [.scale: [ramp(.scale, (1 + pullBackZoom * amount, 1), start: start, duration: duration, easing: .longSettle)]]
        case .drift:
            // Constant speed: a steady pan and a slow push, in log space; slower in a long scene
            let slowing = min(1, longestDrift / (driftSpeed * max(context.sceneDuration, 1)))
            let travel = slideDirection(move.direction ?? .right) * driftSpeed * slowing * amount * context.canvas.width * duration
            return [
                .positionX: [ramp(.positionX, (0, travel.x), start: start, duration: duration, easing: .linear)],
                .positionY: [ramp(.positionY, (0, travel.y), start: start, duration: duration, easing: .linear)],
                .scale: [ramp(.scale, (1, pow(1 + driftZoom * slowing * amount, duration)), start: start, duration: duration, easing: .linear)]
            ]
        case .pan:
            return pan(to: move.target ?? context.lookAt, zoom: amount, start: start, duration: duration, in: context)
        case .whip:
            // Straight there, not along a zoom path: the frame streaks rather than pulling back to look
            let target = move.target ?? context.lookAt
            return [
                .positionX: [ramp(.positionX, (0, target.x - context.lookAt.x), start: start, duration: duration, easing: .whip)],
                .positionY: [ramp(.positionY, (0, target.y - context.lookAt.y), start: start, duration: duration, easing: .whip)],
                .scale: [ramp(.scale, (1, amount), start: start, duration: duration, easing: .whip)]
            ]
        default:
            return [:]
        }
    }

    /// From `begin` at `start` to `end` `duration` later.
    static func ramp(_ property: MotionProperty, _ values: (begin: Double, end: Double), start: Double, duration: Double, easing: MotionEasing) -> PropertyTrack {
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
        // Words 0.12 s apart, each rising over 0.45 s like a fadeUp
        case .wordByWord: return 0.12 * Double(max(context.words - 1, 0)) + 0.45
        case .type: return Double(context.characters) / typingRate
        // A roll every ~0.5 s
        case .roll: return 0.5 * Double(move.words?.count ?? 1)
        case .rise: return 0.6
        // Half way in 0.6 s and four fifths in 1.2 s (the long settle), easing in for the rest
        case .slideIn: return 2.4
        case .tilt: return 1.2
        case .focus, .detach: return 0.6
        case .stateChange: return 0.2
        case .letters: return letterStagger * Double(max(context.characters - 1, 0)) + letterDuration
        case .kinetic, .voice: return Double(context.characters) / kineticRate
        case .reply: return replyStagger * Double(max(context.words - 1, 0)) + replyFade
        case .wash: return washDuration
        case .shimmer: return rest
        case .show, .hide: return 1e-3
        case .scatter: return scatterDuration
        case .fly: return flyDuration
        case .select: return max(Double(context.characters) / selectRate, selectShortest)
        case .morph: return morphDuration
        // The film's dip (0.17 s) and its fill past the frame (0.4 s)
        case .flood: return ShapeMorph.floodDip + ShapeMorph.floodFill
        case .pop: return popDuration
        case .press: return pressDuration
        case .spin: return spinDuration
        // The pointer stays this long after its press
        case .click: return 0.8
        case .burst: return BurstExpansion.duration
        case .ripple: return BurstExpansion.rippleDuration
        case .scroll:
            let distance = move.target.map { hypot($0.x - context.position.x, $0.y - context.position.y) } ?? 0
            // In-out cubic peaks at 1.5 times its average speed
            return max(0.6, 1.5 * distance / (scrollSpeed * max(context.canvas.height, 1)))
        // Rows 2–2.5 frames apart at 30 fps, each over 30–33 frames, the group within 0.5 s
        case .cascade: return 1.05
        case .push: return min(1.2, rest)
        case .pan: return panDuration(to: move.target ?? context.lookAt, zoom: move.intensity ?? 1, in: context)
        case .whip: return whipDuration
        case .pullBack, .hold: return rest
        case .drift: return rest + driftOverrun
        }
    }

    private static func reveal(_ move: MotionMove, start: Double, duration: Double, in context: MoveContext) -> TextReveal {
        let characters = Double(max(context.characters, 1))
        switch move.kind {
        case .type:
            return TextReveal(style: .type, start: start, stagger: duration / characters, partDuration: 0)
        case .kinetic, .voice:
            return TextReveal(style: move.kind == .voice ? .voice : .kinetic, start: start, stagger: duration / characters, partDuration: 0)
        case .reply:
            let part = min(replyFade, duration)
            return TextReveal(style: .reply, start: start, stagger: (duration - part) / Double(max(context.words - 1, 1)), partDuration: part)
        case .letters:
            let part = min(letterDuration, duration)
            return TextReveal(style: .letter, start: start, stagger: (duration - part) / max(characters - 1, 1), partDuration: part)
        case .lineMask:
            let part = min(0.6, duration)
            return TextReveal(style: .rise, start: start, stagger: (duration - part) / Double(max(context.lines - 1, 1)), partDuration: part)
        case .wordByWord:
            let part = min(0.45, duration)
            return TextReveal(style: .word, start: start, stagger: (duration - part) / Double(max(context.words - 1, 1)), partDuration: part)
        default:
            let part = min(0.3, duration)
            return TextReveal(style: .wipe, start: start, stagger: (duration - part) / max(characters - 1, 1), partDuration: part)
        }
    }

    private static func slideDirection(_ direction: MotionMove.Direction) -> SIMD2<Double> {
        switch direction {
        case .left: [-1, 0]
        case .right: [1, 0]
        case .upward: [0, -1]
        case .downward: [0, 1]
        }
    }

    /// Long enough that the pan's fastest moment stays at ``panSpeed`` (a zoom counted as the
    /// distance its view's edge travels), and at least 0.5 s.
    private static func panDuration(to target: CGPoint, zoom: Double, in context: MoveContext) -> Double {
        let distance = hypot(target.x - context.lookAt.x, target.y - context.lookAt.y) + abs(1 / context.zoom - 1 / zoom) * context.canvas.width / 2
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
    /// closer than at the scene's start, eased with ``MotionEasing/move`` and sampled at 30 Hz: from where the moves before
    /// left it, so a pan in and a pan back out chain.
    private static func pan(to target: CGPoint, zoom: Double, start: Double, duration: Double, in context: MoveContext) -> [MotionProperty: [PropertyTrack]] {
        let width = context.canvas.width / context.zoom
        let path = ZoomPath(from: context.lookAt, width: width, to: target, width: context.canvas.width / zoom)
        let count = max(Int((duration * 30).rounded(.up)), 1)
        var keyframes: [MotionProperty: [Keyframe]] = [:]
        for index in 0...count {
            let fraction = Double(index) / Double(count)
            let view = path.view(at: MotionEasing.move.progress(fraction, duration: duration))
            let time = start + fraction * duration
            keyframes[.positionX, default: []].append(Keyframe(time: time, value: view.center.x - context.lookAt.x))
            keyframes[.positionY, default: []].append(Keyframe(time: time, value: view.center.y - context.lookAt.y))
            keyframes[.scale, default: []].append(Keyframe(time: time, value: width / view.width))
        }
        return keyframes.reduce(into: [:]) { tracks, entry in
            tracks[entry.key] = PropertyTrack(entry.key, keyframes: entry.value).map { [$0] }
        }
    }
}
