//
//  CaptureGeometryTracker.swift
//  Reco
//
//  Created by Diip3sh on 25.09.26.
//

import CoreMedia
import os
import ScreenCaptureKit

/// Records where captured content sits on screen and in the video, from ScreenCaptureKit's
/// per-frame metadata, so input telemetry can map screen locations into the video.
///
/// Fed every video sample on the capture queue. Only changes are kept, so a capture whose
/// geometry never changes yields a single entry.
nonisolated final class CaptureGeometryTracker: @unchecked Sendable {

    private let lock = OSAllocatedUnfairLock()
    private var isEnabled = false
    private var entries: [InputTelemetry.Geometry] = []

    /// The recorded entries, timed on the host clock. Read once the stream has stopped.
    var track: [InputTelemetry.Geometry] {
        lock.withLockUnchecked { entries }
    }

    /// Clears the track and turns recording on or off. Call before the stream starts.
    func reset(isEnabled: Bool) {
        lock.withLockUnchecked {
            self.isEnabled = isEnabled
            entries = []
        }
    }

    /// Records the geometry of a video sample. Called on the capture queue for every sample.
    func record(_ sampleBuffer: CMSampleBuffer) {
        let enabled = lock.withLockUnchecked { isEnabled }
        guard enabled,
              let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[String: Any]],
              let attachments = attachmentsArray.first,
              let geometry = Self.geometry(from: attachments, time: sampleBuffer.presentationTimeStamp.seconds)
        else { return }

        append(geometry)
    }

    /// Stores `geometry` unless it only repeats the last entry.
    func append(_ geometry: InputTelemetry.Geometry) {
        lock.withLockUnchecked {
            guard isEnabled else { return }

            // The time is the one field expected to differ between frames
            if var last = entries.last {
                last.time = geometry.time
                guard last != geometry else { return }
            }
            entries.append(geometry)
        }
    }

    /// Reads the geometry of a complete frame from its `SCStreamFrameInfo` attachments.
    /// Returns `nil` for idle, blank and other incomplete frames, which carry none.
    static func geometry(from attachments: [String: Any], time: Double) -> InputTelemetry.Geometry? {
        guard
            let status = attachments[SCStreamFrameInfo.status.rawValue] as? Int,
            status == SCFrameStatus.complete.rawValue,
            let screenRect = rect(attachments[SCStreamFrameInfo.screenRect.rawValue]),
            let contentRect = rect(attachments[SCStreamFrameInfo.contentRect.rawValue]),
            let contentScale = attachments[SCStreamFrameInfo.contentScale.rawValue] as? CGFloat,
            let scaleFactor = attachments[SCStreamFrameInfo.scaleFactor.rawValue] as? CGFloat
        else { return nil }

        return InputTelemetry.Geometry(
            time: time,
            screenRect: screenRect,
            contentRect: contentRect,
            boundingRect: rect(attachments[SCStreamFrameInfo.boundingRect.rawValue]),
            contentScale: contentScale,
            scaleFactor: scaleFactor
        )
    }

    /// Rect attachments are `CGRect` dictionary representations.
    private static func rect(_ value: Any?) -> CGRect? {
        guard let dictionary = value as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: dictionary as CFDictionary)
    }
}
