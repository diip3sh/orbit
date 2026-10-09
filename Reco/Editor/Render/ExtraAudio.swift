//
//  ExtraAudio.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import CoreMedia
import Foundation

/// Audio the editor adds to the recording's own tracks, as files on the recording's timeline.
nonisolated struct ExtraAudio: Equatable, Sendable {

    /// The recording's tracks with their voice isolated (see ``VoiceEnhancer``), by track ID, played in the track's
    /// place; the fast parts of such a track are sped up from this file. `nil` inside for a track whose file couldn't
    /// be rendered, which plays as it is: the keys are what was asked for, so a failure isn't asked again on every edit.
    var enhanced: [CMPersistentTrackID: URL?] = [:]

    /// The enhanced file track `trackID` plays from, if it has one.
    func enhancedFile(for trackID: CMPersistentTrackID) -> URL? {
        enhanced[trackID].flatMap { $0 }
    }

    /// The click sounds at every press (see ``ClickSound``), once they are written.
    var clicks: URL?

    /// The chosen music, once its bookmark is resolved. Looped under the whole output (see ``CompositionBuilder``).
    var background: URL?

    /// The recording's and the click sounds' audio of each part at another speed, sped up (see ``SpeedAudio``).
    var fastParts: [SpeedAudio.Part: URL] = [:]
}
