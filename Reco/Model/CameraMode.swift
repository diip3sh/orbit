//
//  CameraMode.swift
//  Reco
//

import Foundation

/// What the camera records into when it's on.
nonisolated enum CameraMode: String, CaseIterable, Sendable {

    /// Its own file, placed and styled in the editor.
    case track

    /// The system's Presenter Overlay, composited into the screen's video for good.
    case presenterOverlay
}
