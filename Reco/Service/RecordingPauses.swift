//
//  RecordingPauses.swift
//  Reco
//
//  Created by Diip3sh on 25.09.26.
//

import CoreMedia

/// The pauses in a recording, on the host clock that ScreenCaptureKit timestamps samples with.
///
/// The capture keeps running while paused and every sample captured during a pause is dropped.
/// The paused time is cut from the output, so the recording carries on where it was paused.
nonisolated struct RecordingPauses {

    /// Pauses that have been resumed, oldest first.
    private(set) var finished: [Range<CMTime>] = []

    /// When the pause in progress started, `nil` while recording.
    private(set) var pauseStart: CMTime?

    /// The combined length of the finished pauses.
    private(set) var total: CMTime = .zero

    var isPaused: Bool {
        pauseStart != nil
    }

    /// Every pause in seconds; one still in progress ends at infinity.
    var intervals: [Range<Double>] {
        var pauses = finished
        if let pauseStart {
            pauses.append(pauseStart..<CMTime.positiveInfinity)
        }
        return pauses.map { $0.lowerBound.seconds..<$0.upperBound.seconds }
    }

    mutating func pause(at time: CMTime) {
        guard pauseStart == nil else { return }
        pauseStart = time
    }

    mutating func resume(at time: CMTime) {
        guard let pauseStart else { return }
        self.pauseStart = nil
        guard time > pauseStart else { return }
        finished.append(pauseStart..<time)
        total = CMTimeAdd(total, time - pauseStart)
    }

    /// The paused time to cut before a sample spanning `start` to `end`, or `nil` when the sample
    /// is dropped: it overlaps the pause in progress, or was captured before the last resume.
    func pausedTime(start: CMTime, end: CMTime) -> CMTime? {
        if let pauseStart, end > pauseStart {
            return nil
        }
        if let lastResume = finished.last?.upperBound, start < lastResume {
            return nil
        }
        return total
    }
}
