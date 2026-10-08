//
//  MotionSound.swift
//  Reco
//

import Foundation

/// A motion video's sound (spec 0013): a score and quiet effects made for its own picture by
/// ``SoundCueSheet``, each on or off, and raised or lowered from where the rules put it. Every video has
/// both unless its document says otherwise.
nonisolated struct MotionSound: Equatable, Sendable {

    /// The music: chords a shot, the hits that open acts, the closing.
    var score = true

    /// Keys, results, presses, whips and the quiet accents on cuts.
    var effects = true

    /// Decibels added to each.
    var scoreLevel = 0.0
    var effectsLevel = 0.0

    /// How far either level moves: 24 dB down is nearly gone; 6 up is as far as the master's ceiling leaves
    /// room for.
    static let levels = -24.0...6.0

    var isSilent: Bool {
        !score && !effects
    }
}

// MARK: - Codable

nonisolated extension MotionSound: Codable {

    init(from decoder: any Decoder) throws {
        let defaults = MotionSound()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decodeIfPresent(Bool.self, forKey: .score) ?? defaults.score
        effects = try container.decodeIfPresent(Bool.self, forKey: .effects) ?? defaults.effects
        scoreLevel = try container.decodeIfPresent(Double.self, forKey: .scoreLevel) ?? defaults.scoreLevel
        effectsLevel = try container.decodeIfPresent(Double.self, forKey: .effectsLevel) ?? defaults.effectsLevel
    }
}
