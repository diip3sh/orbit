//
//  MoveExpansion+Flow.swift
//  Reco
//

import CoreGraphics

/// Flow films' moves (spec 0016), measured on IrukaDark's launch reel (`~/Movies/Reco/references/new/ref-b.mp4`): its dolphin
/// flying in onto its name, a selection dragged across an error.
nonisolated extension MoveExpansion {

    /// The dolphin came in from the top right and landed by its name in about 0.85 s (6.17–7.0 s), and from the bottom left at
    /// the end (38.0–38.9 s).
    static let flyDuration = 0.9

    /// It starts 0.6 of the frame's width to the side and 0.3 of its height above or below, at 0.7 of its size, turned 30°.
    static let flyReach = (across: 0.6, along: 0.3)
    static let flyFrom = 0.7
    static let flyTurn = 30.0

    /// "Error 520 Something went wrong" (29 characters, two lines) was selected in about 0.45 s: 60 characters a second, never
    /// quicker than 0.35 s.
    static let selectRate = 60.0
    static let selectShortest = 0.35

    /// A fly: from off to the side it travels away from (`direction`, left by default: in from the right, above), across fast
    /// and down late so it swoops, turned at first and banking level past it as it lands, growing to its size.
    static func flyTracks(of move: MotionMove, start: Double, duration: Double, in context: MoveContext) -> [MotionProperty: [PropertyTrack]] {
        let amount = move.intensity ?? 1
        let (width, height) = (context.canvas.width * flyReach.across * amount, context.canvas.height * flyReach.along * amount)
        // Where it starts from its place (y down), and which way across is the long, fast part of its path
        let (from, across): (CGPoint, Bool) = switch move.direction ?? .left {
        case .left: (CGPoint(x: width, y: -height), true)
        case .right: (CGPoint(x: -width, y: -height), true)
        case .upward: (CGPoint(x: -height, y: width), false)
        case .downward: (CGPoint(x: height, y: -width), false)
        }
        let turn = flyTurn * amount * (from.x > 0 ? -1 : 1)
        let flight = { (property: MotionProperty, begin: Double, easing: MotionEasing) in
            ramp(property, (begin, 0), start: start, duration: duration, easing: easing)
        }
        return [
            .positionX: [flight(.positionX, from.x, across ? .cascade : .scroll)],
            .positionY: [flight(.positionY, from.y, across ? .scroll : .cascade)],
            .rotationZ: [flight(.rotationZ, turn, .overshoot)],
            .scale: [ramp(.scale, (flyFrom, 1), start: start, duration: duration, easing: .enter)],
            .opacity: [ramp(.opacity, (0, 1), start: start, duration: min(0.1, duration), easing: .enterFast)]
        ]
    }
}
