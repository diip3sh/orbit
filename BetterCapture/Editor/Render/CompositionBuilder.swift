//
//  CompositionBuilder.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation

/// Builds what the player shows and export writes: the recording, drawn by ``EditorCompositor``
/// with a render plan.
enum CompositionBuilder {

    static func videoComposition(for source: EditorSource, plan: RenderPlan) -> AVVideoComposition {
        let composition = AVMutableVideoComposition()
        composition.customVideoCompositorClass = EditorCompositor.self
        composition.renderSize = source.naturalSize
        composition.frameDuration = CMTime(seconds: 1 / source.frameRate, preferredTimescale: source.timescale)
        composition.instructions = [EditorInstruction(timeRange: source.timeRange, sourceTrackID: source.videoTrackID, plan: plan)]
        return composition
    }
}
