//
//  SettingsStore+CursorCapture.swift
//  Reco
//

import Foundation

extension SettingsStore {

    /// Whether the system cursor stays in the video while input telemetry is recorded. Off by
    /// default: the cursor is left out so the editor can redraw it from telemetry.
    var keepSystemCursorInVideo: Bool {
        get {
            access(keyPath: \.keepSystemCursorInVideo)
            return defaults.bool(forKey: "keepSystemCursorInVideo")
        }
        set {
            withMutation(keyPath: \.keepSystemCursorInVideo) {
                defaults.set(newValue, forKey: "keepSystemCursorInVideo")
            }
        }
    }

    /// Whether the cursor is left out of the video for the editor to draw. Show Cursor has no effect then.
    var leavesCursorToEditor: Bool {
        recordInputTelemetry && !keepSystemCursorInVideo
    }

    /// Whether the capture draws the system cursor into the video.
    var capturesCursor: Bool {
        showCursor && !leavesCursorToEditor
    }
}
