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
    case unreadableBackground

    var errorDescription: String? {
        switch self {
        case .unreadableVideo(let error):
            "The recording couldn't be opened. \(error.localizedDescription)"
        case .noVideoTrack:
            "The recording has no video."
        case .noTelemetry:
            """
            Recorded without input telemetry, so there's no auto-zoom, smooth cursor, click highlights or keystrokes. \
            Turn on Record Input Telemetry in Settings → Video → Advanced, then record again.
            """
        case .unreadableTelemetry(let error):
            """
            The input telemetry couldn't be read, so there's no auto-zoom, smooth cursor, click highlights or \
            keystrokes. \(error.localizedDescription)
            """
        case .unreadableProject(let error):
            "The recording's edits couldn't be read. \(error.localizedDescription)"
        case .projectNotSaved(let error):
            "Edits couldn't be saved. \(error.localizedDescription)"
        case .exportFailed(let error):
            "The video couldn't be exported. \(error.localizedDescription)"
        case .unreadableBackground:
            "The background image couldn't be opened, so its color is shown instead."
        }
    }
}
