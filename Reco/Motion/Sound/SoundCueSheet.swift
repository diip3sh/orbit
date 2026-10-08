//
//  SoundCueSheet.swift
//  Reco
//

import Foundation

/// Everything a video's sound is made from (spec 0013): the score's chords and air, and every cue, timed
/// from the plan by ``SoundRules``. The same document gives the same sheet, and the same sheet the same
/// sound, so a sheet names its sound in the bundle's cache (``SoundCache``).
nonisolated struct SoundCueSheet: Codable, Equatable, Sendable {

    /// A held chord of the score: a pad of detuned saws, warm and slow.
    nonisolated struct Chord: Codable, Equatable, Sendable {
        /// MIDI notes, and the bass's under them.
        var notes: [Int]
        var bass: Int?

        /// In seconds into the video; it rings on for ``release`` after its end.
        var start: Double
        var end: Double

        /// Its RMS in dB, which it reaches after ``attack`` and moves by ``swell`` dB by its end.
        var level: Double
        var attack = 0.12
        var release = 0.5
        var swell = 0.0

        /// Where its harmonics fade, in Hz: higher is brighter.
        var brightness = 1500.0
    }

    /// Band-passed noise under the shots, so the score never drops to digital silence.
    nonisolated struct Air: Codable, Equatable, Sendable {
        var start: Double
        var end: Double
        var level: Double
    }

    /// How long the sound is: the video's whole frames.
    var length = 0.0

    var chords: [Chord] = []
    var air: Air?
    var cues: [SoundCue] = []

    /// The cut to black: the room's tail stops with the picture there.
    var roomStop: Double?

    var isSilent: Bool {
        chords.isEmpty && air == nil && cues.isEmpty
    }
}
