//
//  EditorSource.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation

/// A recording opened in the editor: the video's properties and its input telemetry.
nonisolated struct EditorSource: Sendable {
    let asset: AVURLAsset

    /// The asset's exact extent, which the video composition must cover.
    let timeRange: CMTimeRange

    let videoTrackID: CMPersistentTrackID

    /// The recorder writes system audio before the microphone.
    let audioTrackIDs: [CMPersistentTrackID]

    /// The video's dimensions in pixels.
    let naturalSize: CGSize

    let frameRate: Double

    /// The video track's time scale, for converting seconds to `CMTime`.
    let timescale: CMTimeScale

    let dynamicRange: DynamicRange

    /// `nil` when the recording has none or it couldn't be read; ``telemetryError`` says which.
    let telemetry: InputTelemetry?

    /// Why ``telemetry`` is `nil`.
    let telemetryError: EditorError?

    /// The video's length in seconds.
    var duration: Double {
        timeRange.duration.seconds
    }

    /// Names for the audio tracks, in order. With a single track, which one was recorded isn't known.
    var audioTrackNames: [String] {
        switch audioTrackIDs.count {
        case 1: ["Audio"]
        case 2: ["System Audio", "Microphone"]
        default: audioTrackIDs.indices.map { "Audio \($0 + 1)" }
        }
    }
}
