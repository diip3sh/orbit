//
//  CameraTake.swift
//  Reco
//

import CoreMedia
import Foundation

/// A finished camera file and what's needed to line it up with the screen's.
nonisolated struct CameraTake: Sendable {
    let movie: URL

    /// The first frame written, on the host clock.
    let firstFrame: CMTime

    /// The finished pauses, on the host clock.
    let pauses: [Range<CMTime>]

    /// Where the file starts on the screen recording's timeline, in seconds: its first frame minus the screen's start,
    /// each with the pauses before it cut, as they are from both files. Negative when the camera was running first.
    /// A pause before the screen's start counts on both sides, so it cancels: the screen's writer forgets those.
    ///
    /// - Parameter screenStart: The screen's writer's session start, its file's time zero on the host clock. That's
    ///   the first sample of any track, so an offset from it holds even when audio arrived before the first frame.
    func offset(screenStart: CMTime) -> Double {
        (uncut(firstFrame) - uncut(screenStart)).seconds
    }

    func discard() {
        try? FileManager.default.removeItem(at: movie)
    }

    /// `time` less the pauses finished by then.
    private func uncut(_ time: CMTime) -> CMTime {
        pauses.filter { $0.upperBound <= time }.reduce(time) { $0 - ($1.upperBound - $1.lowerBound) }
    }
}
