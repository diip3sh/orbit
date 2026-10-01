//
//  KeystrokeOverlayStyle.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// How key presses are shown: a chip with the latest one at the bottom of the video.
nonisolated struct KeystrokeOverlayStyle: Codable, Equatable, Sendable {
    var isEnabled = true

    /// Whether typing is shown too, not only shortcuts (keys pressed with ⌘, ⌃ or ⌥) and special
    /// keys. Off by default: the telemetry holds everything typed, passwords included.
    var showsAllKeys = false
}
