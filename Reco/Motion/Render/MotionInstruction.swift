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

    /// The placeholder track that drives the frames (``MotionCompositionBuilder``); its pixels are unused.
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid

    let plan: MotionPlan

    init(timeRange: CMTimeRange, placeholderTrackID: CMPersistentTrackID, plan: MotionPlan) {
        self.timeRange = timeRange
        self.plan = plan
        requiredSourceTrackIDs = [NSNumber(value: placeholderTrackID)]
    }
}
