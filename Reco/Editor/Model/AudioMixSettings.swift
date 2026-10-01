//
//  AudioMixSettings.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import Foundation

/// The volume of each of the recording's audio tracks.
nonisolated struct AudioMixSettings: Codable, Equatable, Sendable {

    /// One per audio track, in the recording's order. Tracks past the end play unchanged.
    var tracks: [Track] = []

    /// The settings of audio track `index`, which exist for every track.
    subscript(track index: Int) -> Track {
        get { index < tracks.count ? tracks[index] : Track() }
        set {
            if index >= tracks.count {
                tracks += Array(repeating: Track(), count: index + 1 - tracks.count)
            }
            tracks[index] = newValue
        }
    }

    nonisolated struct Track: Codable, Equatable, Sendable {

        /// From 0 to 1, the range `AVAudioMix` takes.
        var volume = 1.0

        /// Silences the track without losing its volume.
        var isMuted = false

        /// What the track plays at.
        var effectiveVolume: Float {
            isMuted ? 0 : Float(volume)
        }
    }
}
