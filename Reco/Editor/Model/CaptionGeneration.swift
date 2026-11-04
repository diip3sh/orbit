//
//  CaptionGeneration.swift
//  Reco
//

import Foundation

/// The state of the Captions tab's Generate. Not saved in the project.
nonisolated struct CaptionGeneration: Equatable, Sendable {

    /// How far it is, or `nil` when it isn't running.
    var progress: CaptionProgress?

    /// What it has to say about how it went.
    var notice: String?

    /// The languages it can listen for, by locale identifier.
    var languages: [String] = []

    /// The one chosen: the Mac's at first, since a recording usually speaks that.
    var language: String?
}
