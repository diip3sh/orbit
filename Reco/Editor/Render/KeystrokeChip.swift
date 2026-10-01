//
//  KeystrokeChip.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// A key press shown as a chip, placed when the render plan is built.
nonisolated struct KeystrokeChip: Equatable, Sendable {

    /// Source time of the press.
    var time: Double

    /// The chip's image in ``RenderPlan/chipImages``.
    var image: Int

    /// How long a chip shows, unless the next press replaces it sooner. It fades out over the last
    /// ``fadeDuration`` of it.
    static let holdDuration = 1.5
    static let fadeDuration = 0.3

    /// The chip showing at `time` and its opacity: the latest press, until it has been held.
    /// - Parameter chips: Sorted by time.
    static func visible(in chips: [KeystrokeChip], at time: Double) -> (chip: KeystrokeChip, opacity: Double)? {
        let next = chips.partitioningIndex { $0.time > time }
        guard next > 0 else { return nil }
        let chip = chips[next - 1]
        let remaining = holdDuration - (time - chip.time)
        guard remaining > 0 else { return nil }
        return (chip, min(remaining / fadeDuration, 1))
    }
}
