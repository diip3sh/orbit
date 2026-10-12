//
//  MotionToolStatus.swift
//  Reco
//

/// How `capture_ui` or `preview_motion` went: still working after the tool's wait, or what it found.
nonisolated struct MotionToolStatus: Encodable, Equatable, Sendable {

    nonisolated enum Status: String, Encodable, Sendable {
        case working, done, failed
    }

    var status: Status

    /// The video's UI and the size each was captured at.
    var assets: [MotionSummary.Asset]?

    /// The contact sheet's frames, left to right and top to bottom.
    var frames: [Frame]?

    /// What the design check sees in the frames.
    var findings: [String]?

    /// What the grammar's rules find, with the UI's sizes known.
    var lint: [MotionSummary.Finding]?

    /// The sound made for the video, as an export will have it.
    var sound: Sound?
    var error: String?

    nonisolated struct Sound: Encodable, Equatable, Sendable {
        var cues: Int

        /// Integrated, in LUFS: the master holds every video at −16.
        var loudness: Double
    }

    nonisolated struct Frame: Encodable, Equatable, Sendable {
        var scene: String

        /// Seconds into the video.
        var time: Double
    }
}
