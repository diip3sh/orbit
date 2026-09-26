//
//  EditorSource.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation

/// A recording opened in the editor: the video's properties and its input telemetry.
nonisolated struct EditorSource: Sendable {
    let asset: AVURLAsset

    /// The video's length in seconds.
    let duration: Double

    /// The video's dimensions in pixels.
    let naturalSize: CGSize

    let frameRate: Double

    /// The video track's time scale, for converting seconds to `CMTime`.
    let timescale: CMTimeScale

    /// `nil` when the recording has none or it couldn't be read; ``telemetryError`` says which.
    let telemetry: InputTelemetry?

    /// Why ``telemetry`` is `nil`.
    let telemetryError: EditorError?
}
