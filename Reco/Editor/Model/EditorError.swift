//
//  EditorError.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// Everything that can go wrong in the editor, worded to be shown in its window.
nonisolated enum EditorError: LocalizedError {
    case unreadableVideo(any Error)
    case noVideoTrack
    case noTelemetry
    case unreadableTelemetry(any Error)
    case unreadableProject(any Error)
    case projectNotSaved(any Error)
    case exportFailed(any Error)
    case frameNotCopied(any Error)
    case unreadableBackground
    case unreadableBackgroundAudio
    case renameFailed(any Error)
    case styleNotSaved(any Error)
    case unreadableStyle(any Error)
    case cameraFootageNotAdded(any Error)
    case noFreeOverlayLane
    case noRoomForOverlay
    case unreadableOverlayImage

    var errorDescription: String? {
        switch self {
        case .unreadableVideo(let error):
            String(localized: "The recording couldn't be opened. \(error.localizedDescription)")
        case .noVideoTrack:
            String(localized: "The recording has no video.")
        case .noTelemetry:
            String(localized: """
            Recorded without input telemetry, so there's no auto-zoom, smooth cursor, click highlights or keystrokes. \
            Turn on Record Input Telemetry in Settings → Video → Advanced, then record again.
            """)
        case .unreadableTelemetry(let error):
            String(localized: """
            The input telemetry couldn't be read, so there's no auto-zoom, smooth cursor, click highlights or \
            keystrokes. \(error.localizedDescription)
            """)
        case .unreadableProject(let error):
            String(localized: "The recording's edits couldn't be read. \(error.localizedDescription)")
        case .projectNotSaved(let error):
            String(localized: "Edits couldn't be saved. \(error.localizedDescription)")
        case .exportFailed(let error):
            String(localized: "The video couldn't be exported. \(error.localizedDescription)")
        case .frameNotCopied(let error):
            String(localized: "The frame couldn't be copied. \(error.localizedDescription)")
        case .unreadableBackground:
            String(localized: "The background image couldn't be opened, so its color is shown instead.")
        case .unreadableBackgroundAudio:
            String(localized: "The background audio couldn't be opened, so it's left out.")
        case .renameFailed(let error):
            String(localized: "The recording couldn't be renamed. \(error.localizedDescription)")
        case .styleNotSaved(let error):
            String(localized: "The style couldn't be saved. \(error.localizedDescription)")
        case .unreadableStyle(let error):
            String(localized: "The style couldn't be read. \(error.localizedDescription)")
        case .cameraFootageNotAdded(let error):
            String(localized: "The camera footage couldn't be added. \(error.localizedDescription)")
        case .noFreeOverlayLane:
            String(localized: "All three overlay lanes are taken at the playhead, so there's no room for another. Move the playhead, or move or delete an overlay.")
        case .noRoomForOverlay:
            String(localized: "The playhead is too close to the recording's end for an overlay. Move it back.")
        case .unreadableOverlayImage:
            String(localized: "The picture couldn't be read, so it wasn't added.")
        }
    }
}
