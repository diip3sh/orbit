//
//  EditorInstruction.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation

/// Carries a render plan to ``EditorCompositor``. A new instruction is created for every plan.
///
/// `@unchecked` only because `NSValue` isn't annotated `Sendable`; every property is immutable.
nonisolated final class EditorInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false

    /// Frames differ even when the source doesn't, e.g. while a click highlight fades.
    let containsTweening = true

    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid

    let sourceTrackID: CMPersistentTrackID
    let plan: RenderPlan

    init(timeRange: CMTimeRange, sourceTrackID: CMPersistentTrackID, plan: RenderPlan) {
        self.timeRange = timeRange
        self.sourceTrackID = sourceTrackID
        self.plan = plan
        requiredSourceTrackIDs = [NSNumber(value: sourceTrackID)]
    }
}
