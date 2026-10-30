//
//  CaptionWord.swift
//  Reco
//

import Foundation

/// One word of a caption. Times are source seconds.
nonisolated struct CaptionWord: Codable, Equatable, Sendable {
    var text: String
    var range: Range<Double>

    /// How sure the transcriber was, from 0 to 1. A word typed by hand is 1.
    var confidence: Double
}
