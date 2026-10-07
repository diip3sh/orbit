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

    /// The volume of a click sound at every press, from 0 (none) to 1. Here because it is mixed audio: the plan
    /// doesn't depend on it.
    var clickVolume = 0.0

    /// Music looped under the whole video, if one was chosen.
    var background: BackgroundAudio?

    /// Whether the mix has audio of its own, besides the recording's tracks.
    var addsAudio: Bool {
        clickVolume > 0 || background != nil
    }

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

// MARK: - Decoding

extension AudioMixSettings {

    /// Settings added after a project was saved take their defaults when missing.
    nonisolated init(from decoder: any Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tracks = try container.decodeIfPresent([Track].self, forKey: .tracks) ?? tracks
        clickVolume = try container.decodeIfPresent(Double.self, forKey: .clickVolume) ?? clickVolume
        background = try container.decodeIfPresent(BackgroundAudio.self, forKey: .background)
    }
}
