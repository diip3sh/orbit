//
//  CaptionTrack.swift
//  Reco
//

import Foundation

/// A recording's captions: whether they're drawn on the video, how, and what they say.
nonisolated struct CaptionTrack: Codable, Equatable, Sendable {

    /// Whether the video shows them. Subtitle files don't depend on it.
    var isEnabled = true

    var style = CaptionStyle()

    /// Sorted and apart.
    var cues: [CaptionCue] = []

    /// Whether someone changed the cues since they were generated, so generating again would lose work.
    var hasEditedCues = false
}
