//
//  SoundRules+Editorial.swift
//  Reco
//

import Foundation

/// An editorial film's score (spec 0017), measured on ElevenLabs' launch film's music with its voice taken out
/// (`~/Movies/Reco/references/elevenlabs-launch.mp4`): no drums and no steady beat, but a score cut to the picture. Its harmony
/// changes with the sections, not every cut; a sub boom and a low thump land a sixteenth after a section's cut (157 ms
/// measured); 10.2 kHz ticks mark typing and the cuts between; a breakdown keeps only a drone and the pad; the tonic's major
/// is the loudest moment; the end card gets a burst on the mark and on the name, and a tail gone 1.5 s before the end.
nonisolated extension SoundRules {

    /// A new section starts at a cut at least this long after the last one began: its harmony held 2.5 s or more.
    static let shortestSection = 2.5

    /// The grid hits are placed on: the film's second half cut on beats at 89.3 BPM.
    static let editorialTempo = 90.0

    /// G♯ and its chords as the film's sections took them (MIDI notes, the bass under them): the opening's open fifth with
    /// no bass, the body's iv9, ♭VImaj9, ♭VIIadd9 and borrowed IVmaj9, the breakdown's ♭III6 over its drone, the return's
    /// iv9 and ♭III over its third, the lift's I7sus4, then I.
    static let editorialOpening = (notes: [56, 63, 68, 75], bass: Int?.none)
    static let editorialBody: [(notes: [Int], bass: Int)] = [
        ([52, 56, 59, 63, 68], 37), ([56, 59, 63, 66, 71], 28), ([54, 58, 61, 68], 30), ([53, 56, 61, 63, 65, 72], 37)
    ]
    static let editorialReturn: [(notes: [Int], bass: Int)] = [([52, 56, 59, 63, 68], 37), ([51, 54, 58, 61, 66], 39)]
    static let editorialBreakdown = (notes: [47, 51, 59, 63, 68], bass: 35)
    static let editorialLift = (notes: [49, 54, 61, 63, 68], bass: 32)
    static let editorialTonic = (notes: [51, 56, 60, 63, 68, 72], bass: 32)

    /// The pads' RMS, attack, swell (dB over the chord) and brightness: dark (most of their energy at 300–570 Hz), swelling
    /// into the next section; the opening in from nothing, the breakdown down and swelling back into the return, the peak
    /// the loudest, the end card's tail gone in 3.5 s.
    static let editorialPads = (
        opening: (level: -33.0, attack: 1.4, swell: 4.0, brightness: 700.0),
        body: (level: -31.0, attack: 0.3, swell: 5.0, brightness: 520.0),
        breakdown: (level: -34.0, attack: 0.4, swell: 8.0, brightness: 400.0),
        lift: (level: -33.0, attack: 0.2, swell: 4.0, brightness: 600.0),
        peak: (level: -28.0, attack: 0.15, swell: 3.0, brightness: 750.0),
        tail: (level: -30.0, attack: 0.03, swell: -30.0, brightness: 700.0)
    )
    static let editorialTailLength = 3.5

    /// A section's cut: a sub boom on its chord's bass, an octave down from C♯2 (34.6 Hz at the lowest, over the master's
    /// 30 Hz rumble filter) with the bass itself 8 dB under it, held 1.5 s, and a thump sliding an octave down with it; the
    /// return's 3 dB up. The first one after the opening rises in on air. The film's booms sat on G♯1–C♯2: dropped alone, the
    /// rebuilt film's score had 7 % of its power at 60–150 Hz against the film's 20; with the bass under it, 22 (69 % under 60
    /// Hz, as the film's).
    static let editorialBoom = (length: 1.5, level: -11.0, returnLift: 3.0, octave: -8.0)
    static let editorialThump = (high: 63.0, low: 34.0, length: 1.0, decay: 0.13, level: -8.0)
    static let editorialRiser = (length: 0.3, low: 300.0, high: 3000.0, power: 2.0, level: -19.0)

    /// A tick on a cut inside a section, and each typed character's, no closer than 0.11 s (runs 0.11–0.17 s apart).
    static let editorialTick = (level: -22.0, spacing: 0.11, pan: 0.2)

    /// The lift's low hit echoing: six times, a triplet eighth apart, 5 dB down each time.
    static let editorialEcho = (count: 6, fall: -5.0)

    /// The end card's bursts: air into a thump falling 78 → 46 Hz, on the mark and again on the name.
    static let editorialBurst = (swish: 0.35, high: 78.0, low: 46.0, length: 0.8, decay: 0.15, level: -14.0, name: 0.8)

    /// Mastered as the beat scores are, under the limiter: the thumps peak about 20 dB over the music's loudness.
    static let editorialFinish = SoundCueSheet.Finish(loudness: -16, ceiling: -1)
}
