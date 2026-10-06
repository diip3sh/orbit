//
//  Keyframe.swift
//  Reco
//

import Foundation

/// A property's value at a time in its scene. `easing` shapes the way to the next keyframe, as a
/// CSS keyframe's timing function does.
nonisolated struct Keyframe: Codable, Equatable, Sendable {

    /// Seconds from the scene's start.
    var time: Double

    var value: Double

    var easing = MotionEasing.linear

    init(time: Double, value: Double, easing: MotionEasing = .linear) {
        self.time = time
        self.value = value
        self.easing = easing
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decode(Double.self, forKey: .time)
        value = try container.decode(Double.self, forKey: .value)
        easing = try container.decodeIfPresent(MotionEasing.self, forKey: .easing) ?? .linear
    }
}
