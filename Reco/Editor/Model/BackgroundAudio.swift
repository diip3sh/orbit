//
//  BackgroundAudio.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import Foundation

/// The music chosen for under the whole video: a file the user picked, kept as a security-scoped bookmark like the
/// canvas's picture, and its own volume and mute.
nonisolated struct BackgroundAudio: Codable, Equatable, Sendable {

    var bookmark: Data

    /// The file's name without its extension, for the inspector.
    var name: String

    /// Quiet by default: music under a recording's own sound is background.
    var track = AudioMixSettings.Track(volume: 0.3)
}
