//
//  PropertyTrack.swift
//  Reco
//

import Foundation

/// A property's keyframes, sorted by time, and its value at any time: the first value before them,
/// the last after them, eased in between. Scale moves in log space, so zooming in and out by the
/// same factor looks equally fast.
nonisolated struct PropertyTrack: Equatable, Sendable {
    let property: MotionProperty
    let keyframes: [Keyframe]

    /// `nil` without keyframes.
    init?(_ property: MotionProperty, keyframes: [Keyframe]) {
        guard !keyframes.isEmpty else { return nil }
        self.property = property
        self.keyframes = keyframes.sorted { $0.time < $1.time }
    }

    /// One way from `start` to `end`.
    init(_ property: MotionProperty, from start: Keyframe, to end: Keyframe) {
        self.property = property
        keyframes = [start, end]
    }

    func value(at time: Double) -> Double {
        // The first keyframe after `time`
        let next = keyframes.partitioningIndex { $0.time > time }
        guard next > 0 else { return keyframes[0].value }
        guard next < keyframes.count else { return keyframes[next - 1].value }

        let (start, end) = (keyframes[next - 1], keyframes[next])
        let duration = end.time - start.time
        let progress = start.easing.progress((time - start.time) / duration, duration: duration)
        if property == .scale, start.value > 0, end.value > 0 {
            return exp(log(start.value) + (log(end.value) - log(start.value)) * progress)
        }
        return start.value + (end.value - start.value) * progress
    }
}
