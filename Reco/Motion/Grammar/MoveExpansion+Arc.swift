//
//  MoveExpansion+Arc.swift
//  Reco
//

/// The camera travelling round where it looks (spec 0020).
nonisolated extension MoveExpansion {

    /// An arc turns the scene this many degrees a second: a camera on a slider passing a product (est.).
    static let arcSpeed = 2.5

    /// The camera going `way` round turns the scene the other: rightwards, its left edge goes away; upwards, its top comes near.
    static func arcTracks(turning way: SIMD2<Double>, start: Double, duration: Double) -> [MotionProperty: [PropertyTrack]] {
        let turn = way * arcSpeed * duration
        return [
            .rotationY: [ramp(.rotationY, (0, -turn.x), start: start, duration: duration, easing: .linear)],
            .rotationX: [ramp(.rotationX, (0, turn.y), start: start, duration: duration, easing: .linear)]
        ]
    }
}
