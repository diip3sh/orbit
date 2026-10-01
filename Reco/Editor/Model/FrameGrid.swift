//
//  FrameGrid.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// The frames of a constant frame rate video, frame `n` starting at `n / frameRate`. Recordings
/// are written on this grid (see `AssetWriter`), so seeking to a frame's start lands on it exactly.
///
/// Times are compared as frame indices, never as doubles.
nonisolated struct FrameGrid: Equatable, Sendable {
    let frameRate: Double
    let frameCount: Int

    /// Absorbs rounding in `time * frameRate`, so a frame's own start time maps back to it.
    private static let tolerance = 1e-6

    init(frameRate: Double, duration: Double) {
        self.frameRate = frameRate
        frameCount = max(Int((duration * frameRate).rounded()), 1)
    }

    var lastFrame: Int {
        frameCount - 1
    }

    /// The frame on screen at `time`: the last one starting at or before it, clamped to the video.
    func frame(at time: Double) -> Int {
        let frame = Int((time * frameRate + Self.tolerance).rounded(.down))
        return min(max(frame, 0), lastFrame)
    }

    func time(ofFrame frame: Int) -> Double {
        Double(frame) / frameRate
    }
}
