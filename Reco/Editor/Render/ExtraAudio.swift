//
//  ExtraAudio.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation

/// Audio the editor adds to the recording's own tracks, as files on the recording's timeline.
nonisolated struct ExtraAudio: Equatable, Sendable {

    /// The click sounds at every press (see ``ClickSound``), once they are written.
    var clicks: URL?
}
