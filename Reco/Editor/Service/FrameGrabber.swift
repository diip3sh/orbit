//
//  FrameGrabber.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import AVFoundation

/// One frame of the edited video, drawn by its video composition as the player and export draw it.
nonisolated enum FrameGrabber {

    /// The frame at output time `time` in seconds, exactly: a frame's start time gives that frame.
    @concurrent
    static func image(of composition: EditorComposition, at time: Double, timescale: CMTimeScale) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: composition.asset)
        generator.videoComposition = composition.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return try await generator.image(at: CMTime(seconds: time, preferredTimescale: timescale)).image
    }
}
