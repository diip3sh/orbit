//
//  MoveExpansion+Story.swift
//  Reco
//

import CoreGraphics

/// Story films' moves (spec 0015), measured on Lovable's chat launch: replies word by word, a wash, a scattered
/// collage, contents swapping on a beat.
nonisolated extension MoveExpansion {

    /// A reply's words 0.1–0.2 s apart ("Let's explore what the brand could look like", 8 words in 1.1 s), each fading in
    /// over 0.1 s. Voice is typed at kinetic's rate: the dictation ran 12–14 characters a second.
    static let replyStagger = 0.15
    static let replyFade = 0.1

    /// A wash sweeps across in 0.5 s, covers until 0.8 s and is gone by 1.2 s (the prompt box sent at 9.6 s).
    static let washDuration = 1.2

    /// A scatter: a stack in the middle thrown out to a collage in about 0.45 s, a layer every 0.03 s, each from half its
    /// size and turned up to 24° (the product shots at 21.5 s).
    static let scatterDuration = 0.45
    static let scatterStagger = 0.03
    static let scatterFrom = 0.5
    static let scatterTurn = 18.0

    /// What a story move does to its layer's properties. A shimmer and a wash are drawn over its pixels
    /// (``LayerTint``), a group's wash going to its layers; a group's own scatter is its layers' flights
    /// (``DocumentExpansion``).
    static func storyTracks(of move: MotionMove, start: Double, duration: Double, in context: MoveContext) -> [MotionProperty: [PropertyTrack]] {
        switch move.kind {
        case .show, .hide:
            // At once, on its frame: a tile's contents swapping on a beat
            let (before, after) = move.kind == .show ? (0.0, 1.0) : (1.0, 0.0)
            let swap = PropertyTrack(.opacity, from: Keyframe(time: start - 1e-3, value: before, easing: .hold), to: Keyframe(time: start, value: after))
            return [.opacity: [swap]]
        case .scatter:
            guard let from = move.target else { return [:] }
            return scatterTracks(of: move, from: from, start: start, duration: duration, in: context)
        default:
            return [:]
        }
    }

    /// A layer of a scatter, flying from where it was stacked (`from`, in its parent's space: the group's middle) to its
    /// place, growing past its size and turning into its own angle; `intensity` turns it one way or the other.
    private static func scatterTracks(
        of move: MotionMove, from: CGPoint, start: Double, duration: Double, in context: MoveContext
    ) -> [MotionProperty: [PropertyTrack]] {
        let flight = { (property: MotionProperty, begin: Double, end: Double, easing: MotionEasing, length: Double) in
            PropertyTrack(property, from: Keyframe(time: start, value: begin, easing: easing), to: Keyframe(time: start + length, value: end))
        }
        return [
            .positionX: [flight(.positionX, from.x - context.position.x, 0, .enter, duration)],
            .positionY: [flight(.positionY, from.y - context.position.y, 0, .enter, duration)],
            .rotationZ: [flight(.rotationZ, scatterTurn * (move.intensity ?? 1), 0, .enter, duration)],
            .scale: [flight(.scale, scatterFrom, 1, .overshoot, duration)],
            .opacity: [flight(.opacity, 0, 1, .enterFast, min(0.08, duration))]
        ]
    }
}
