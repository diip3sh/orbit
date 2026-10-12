//
//  MotionInstruction.swift
//  Reco
//

import AVFoundation

/// Carries a motion plan to ``MotionCompositor``. A new instruction is created for every plan.
///
/// `@unchecked` only because `NSValue` isn't annotated `Sendable`; every property is immutable.
nonisolated final class MotionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true

    /// The placeholder track that drives the frames (``MotionCompositionBuilder``), whose pixels
    /// are unused, and the live layers' tracks.
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid

    let plan: MotionPlan

    /// The track of each live layer's take.
    let liveTracks: [MotionPlan.LayerKey: CMPersistentTrackID]

    init(timeRange: CMTimeRange, placeholderTrackID: CMPersistentTrackID, liveTracks: [MotionPlan.LayerKey: CMPersistentTrackID], plan: MotionPlan) {
        self.timeRange = timeRange
        self.plan = plan
        self.liveTracks = liveTracks
        requiredSourceTrackIDs = ([placeholderTrackID] + liveTracks.values).map { NSNumber(value: $0) }
    }
}
