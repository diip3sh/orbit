//
//  MoveExpansion+Editorial.swift
//  Reco
//

import CoreGraphics

/// Editorial films' moves (spec 0017), measured on ElevenLabs' launch film (`~/Movies/Reco/references/elevenlabs-launch.mp4`,
/// 60 fps): "Architect" wiped in beside its wordmark, statements lit word by word, mono labels blinking in, a card growing to
/// fill the frame, the wordmark opening out of its mark.
nonisolated extension MoveExpansion {

    /// A sweep: its front's middle crossed "Architect" at about 1350 px/s on a ramp about 180 px wide, so a character of its
    /// 46 px type every 0.02 s, each in over 0.13 s.
    static let sweepStagger = 0.02
    static let sweepFront = 0.13

    /// A brightened line: its first word lit 0.22 s after it starts shrinking, each next one 0.02 s plus 0.045 s a character of
    /// the word before ("to the standards you set": 0.12, 0.18, 0.38 and 0.15 s apart); the line from 1.19× its size, settling
    /// over 1.28 s on an out-expo.
    static let brightenFirst = 0.22
    static let brightenGap = 0.02
    static let brightenPerCharacter = 0.045
    static let brightenGrowth = 0.19
    static let brightenSettle = 1.28
    static let brightenEasing = MotionEasing.cubicBezier(0.04, 0.46, 0, 1)

    /// A blink: on and off a frame at a time at 60 fps for four frames, then it eases 12 px along over 0.25 s (the labels'
    /// text moved 6–20 px away from their bars).
    static let blinkFrame = 1.0 / 60
    static let blinkFlicker = 4
    static let blinkSlide = 0.25
    static let blinkTravel = 12.0

    /// A grow: "Connect Architect to" grew 1152×763 → the frame in 0.38 s, still moving as it filled it; its corners 11.5 → 27 px.
    static let growDuration = 0.4
    static let growEasing = MotionEasing.cubicBezier(0.20, 0.20, 0.03, 0.78)
    static let growRadius = 27.0

    /// The stars of the dark beat went round for 1.4 s; the dots round the sphere were born and gone in 0.84 s.
    static let orbitDuration = 1.4
    static let dotsDuration = 0.84

    /// An unfold: the mark parts over 0.59 s on an expo in-out; the name is typed from 0.37 s, done as the line slides (both
    /// words at once, out from where the mark parted, about 26 letters a second each), at most a letter every 0.035 s; the line
    /// slides to its place from 0.58 s over 0.74 s; the tagline is swept in from 0.93 s; the line, 1.125× as it opens, settles
    /// to its size on a spring (ω ≈ 7.3 rad/s) from 0.72 s.
    static let unfoldPart = 0.59
    static let unfoldPartEasing = MotionEasing.cubicBezier(0.79, 0, 0.15, 1)
    static let unfoldTyping = 0.37
    static let unfoldLetter = 0.035
    static let unfoldSlide = (start: 0.58, duration: 0.74)
    static let unfoldSlideEasing = MotionEasing.cubicBezier(0.92, 0.17, 0.07, 0.91)
    static let unfoldTagline = 0.93
    static let unfoldScale = 1.125
    static let unfoldSettle = (start: 0.72, duration: 1.4, response: 0.86)
    static let unfoldDuration = 2.1

    /// An eat (spec 0018): ElevenLabs' lines left their scenes eaten from both ends by the mark's two bars, ease-in, the bars
    /// meeting in the middle as the cut came: "Your agents" 280 → 39 px in 0.28 s, "Elevate your customer experiences" 989 → 37
    /// px in 0.18 s. The bars start a third of a line outside the text's ends, a fifth of a line wide and three quarters tall.
    static let eatDuration = 0.25
    static let eatEasing = MotionEasing.exit
    static let eatGap = 0.3
    static let eatBar = CGSize(width: 0.2, height: 0.75)

    /// A scene breathing (spec 0018): ElevenLabs' film was frozen in 6 % of its frames before the end card, ours in 26 %. Its shots
    /// opened moving at their fastest, a pull-back half done in 0.12 s and nine tenths in 0.4 s; held, they crept about 2 % a
    /// second; and they left accelerating (the wordmark grew 5 % in its last 0.4 s into the wipe).
    static let breathSettle = (from: 1.04, timeConstant: 0.17)
    static let breathCreep = 0.015
    static let breathLeave = (by: 1.03, duration: 0.4)

    /// A camera's scale tracks breathing over a scene `duration` long: settling in, creeping closer, leaving faster.
    static func breath(over duration: Double) -> [PropertyTrack] {
        let leave = min(breathLeave.duration, duration / 2)
        return [
            ramp(.scale, (breathSettle.from, 1), start: 0, duration: duration, easing: .settle(timeConstant: breathSettle.timeConstant)),
            ramp(.scale, (1, 1 + breathCreep * duration), start: 0, duration: duration, easing: .linear),
            ramp(.scale, (1, breathLeave.by), start: duration - leave, duration: leave, easing: .exit)
        ]
    }

    /// When each word of a brightened line lights after its start, by the characters in `lengths`.
    static func brightenOffsets(_ lengths: [Int]) -> [Double] {
        var offsets: [Double] = []
        for index in lengths.indices {
            offsets.append(index == 0 ? brightenFirst : offsets[index - 1] + brightenGap + brightenPerCharacter * Double(lengths[index - 1]))
        }
        return offsets
    }

    /// What an editorial move does to its layer: a sweep's and a brightened line's reveal, a brightened line's shrink and a
    /// blink's flicker and slide. A grow is the shape's (``ShapeMorph``); an unfold, an orbit and dots are other layers' moves
    /// (``DocumentExpansion``, ``BurstExpansion``); marks are drawn round the layer (``MotionFrameRenderer``).
    static func editorialEffect(of move: MotionMove, start: Double, duration: Double, in context: MoveContext) -> MoveEffect {
        var effect = MoveEffect(tracks: editorialTracks(of: move, start: start, duration: duration, in: context))
        switch move.kind {
        case .sweep:
            let part = min(sweepFront, duration)
            effect.reveal = TextReveal(style: .sweep, start: start, stagger: (duration - part) / Double(max(context.characters - 1, 1)), partDuration: part)
        case .brighten:
            // Its words lit at their measured times, stretched to the move's length
            let offsets = brightenOffsets(context.wordLengths)
            let stretch = duration / max(offsets.last ?? brightenFirst, 1e-3)
            effect.reveal = TextReveal(style: .brighten, start: start, stagger: 0, partDuration: 0, offsets: offsets.map { $0 * stretch })
        default:
            break
        }
        return effect
    }

    /// How long an editorial move takes unless the document says; `rest` is what's left of its scene.
    static func editorialDuration(of kind: MotionMove.Kind, rest: Double, in context: MoveContext) -> Double {
        switch kind {
        case .sweep: sweepStagger * Double(max(context.characters - 1, 0)) + sweepFront
        case .brighten: brightenOffsets(context.wordLengths).last ?? brightenFirst
        case .blink: blinkFrame * Double(blinkFlicker) + blinkSlide
        case .grow: growDuration
        case .orbit: orbitDuration
        case .dots: dotsDuration
        case .unfold: unfoldDuration
        case .eat: min(eatDuration, rest)
        default: rest
        }
    }

    /// A brightened line's shrink and a blink's flicker and slide.
    private static func editorialTracks(of move: MotionMove, start: Double, duration: Double, in context: MoveContext) -> [MotionProperty: [PropertyTrack]] {
        let amount = move.intensity ?? 1
        switch move.kind {
        case .brighten:
            return [.scale: [ramp(.scale, (1 + brightenGrowth * amount, 1), start: start, duration: brightenSettle, easing: brightenEasing)]]
        case .blink:
            // Off before it, then on and off a frame at a time, on from the last
            let flicker = (0...blinkFlicker).map { Keyframe(time: start + Double($0) * blinkFrame, value: $0.isMultiple(of: 2) ? 1 : 0, easing: .hold) }
            let opacity = PropertyTrack(.opacity, keyframes: [Keyframe(time: start - 1e-3, value: 0, easing: .hold)] + flicker)
            let travel = blinkTravel * context.unit * amount * (move.direction == .left ? -1 : 1)
            let settled = start + Double(blinkFlicker) * blinkFrame
            return [
                .opacity: opacity.map { [$0] } ?? [],
                .positionX: [ramp(.positionX, (-travel, 0), start: settled, duration: max(duration - (settled - start), 1e-3), easing: .enter)]
            ]
        default:
            return [:]
        }
    }
}
