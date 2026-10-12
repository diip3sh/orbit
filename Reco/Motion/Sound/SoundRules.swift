//
//  SoundRules.swift
//  Reco
//

import Foundation

/// Every number the cue sheet is made with (spec 0013), each in one place: the hand-made Supabase film's
/// (`score.py`, round 6), whose first score the user called "amazing", and whose closing copies New
/// Raycast's measured one after four closings designed by taste were turned down.
nonisolated enum SoundRules {

    // MARK: - 1. The score follows the edit

    /// A chord a shot, changing this long before each cut; a whip's landing starts a shot too.
    static let chordLead = 0.04

    /// With a scene shorter than this, the chord changes on every second cut instead.
    static let shortestScene = 2.0

    /// A whip landing closer than this to another change keeps the chord: the film's held 1.94 s.
    static let shortestChord = 1.5

    /// D major, walked back from the tonic so the shot before black is always home: …, I, vi, IV, V, I.
    static let progression: [(notes: [Int], bass: Int)] = [
        ([50, 57, 61, 64, 66], 38), ([47, 54, 57, 62, 64], 35), ([43, 50, 54, 57, 59], 31), ([45, 52, 57, 59, 62], 33)
    ]

    /// The first chord swells in from nothing; the ones after rise and brighten towards the last, which
    /// lands with a whip or cut, swells 5 dB into black and stops dead with it.
    static let opening = (level: -32.0, attack: 1.4, swell: 4.0, brightness: 1100.0)
    static let middle = (level: -29.0...(-28.0), brightness: 1300.0...1600.0, release: 0.5)
    static let last = (level: -27.0, attack: 0.03, swell: 5.0, brightness: 2100.0, release: 0.004)

    /// The chord before the last lets go sooner, under its sharp start.
    static let beforeLastRelease = 0.25

    static let airLevel = -46.0

    // MARK: - 2. Hits open acts

    /// The first UI cut in: a glass A5 and D6 over a low hit, air rushing into it.
    static let openingHit = (notes: [81.0, 86.0], levels: [-15.0, -18.0], pans: [-0.1, 0.12], length: 1.8, send: 0.45)
    static let openingThump = (high: 70.0, low: 44.0, decay: 0.14, level: -15.0)
    static let openingSwish = (length: 0.35, level: -26.0)

    /// Other cuts, quiet under the music: a swish into the cut and a thump on it.
    static let cutSwish = (length: 0.3, level: -24.0, send: 0.25)
    static let cutThump = (high: 75.0, low: 45.0, decay: 0.11, level: -19.0)

    // MARK: - 3. Effects for what the viewer sees happen

    static let keyLevel = -14.0
    static let spaceLevel = -12.0
    static let keyPan = -0.12...0.12
    static let keySend = 0.06

    /// Results settling: a blip a word, up D major from F#5, in a field that shows results: one that grows
    /// to at least this many times its empty height. bolt.new's prompt, which never does, popped on every word.
    static let settleNotes = [78.0, 81, 86, 90, 93, 98]
    static let settleLevel = -17.0
    static let resultsGrowth = 1.5

    /// A press: the arrow key, and a high blip as the selection lands 0.06 s later.
    static let pressBlip = (note: 93.0, length: 0.15, delay: 0.06, level: -27.0)

    /// A selection is chosen: Enter this long before its scene cuts to what it opens.
    static let enterLead = 0.14
    static let enterLevel = -11.0

    /// A whip is a pan faster than this, in frame widths a second: the film's and a whip seam's peak near
    /// 10, the camera following a selection near 3, a macro's creep under 0.05.
    static let whipSpeed = 5.0

    /// A whip starts and lands where the camera is down to this share of its fastest.
    static let whipStill = 0.01
    static let whipRiser = (length: 0.4, low: 400.0, high: 1400.0, power: 2.0, level: -26.0)
    static let whooshLevel = -9.0
    static let landingThump = (high: 68.0, low: 38.0, length: 0.9, decay: 0.22, level: -8.0)
    static let landingGlass = (note: 86.0, length: 1.4, brightness: 1.3, delay: 0.01, level: -19.0)

    // MARK: - 3b. Motion design (spec 0014)

    /// A pop: a blip a step up D major each time, from A5, so a row of them climbs.
    static let popNotes = [81.0, 83, 85, 86, 88, 90]
    static let popLevel = -20.0

    /// A press, a click: a key.
    static let pressLevel = -14.0

    /// A flood: a riser into the fill, and a low hit as it covers the frame, this long into the fill.
    static let floodRiser = (length: 0.45, low: 600.0, high: 5000.0, power: 2.0, level: -20.0)
    static let floodThump = (high: 72.0, low: 40.0, length: 1.0, decay: 0.2, level: -12.0, after: 0.12)

    /// A burst: a glass pair, D6 and A6.
    static let burstGlass = (notes: [86.0, 93.0], levels: [-17.0, -22.0], pans: [-0.1, 0.15], length: 1.6, send: 0.5)

    /// A scroll whose average speed passes this many canvas heights a second whooshes at its fastest, its middle.
    static let scrollWhoosh = 0.4

    // MARK: - 4. The closing, Raycast's

    /// The last shot rises into the cut to black, which gets a deep hit.
    static let blackRiser = (length: 1.6, low: 500.0, high: 7000.0, power: 2.6, level: -14.0)
    static let blackThump = (high: 66.0, low: 36.0, length: 1.8, decay: 0.5, level: -7.0)

    /// IV under the words, I at the slide, vi at the dimmed line, V at the logo, each quieter.
    static let wordsChord = SoundCueSheet.Chord(notes: [43, 50, 57, 59, 66], bass: 43, start: 0, end: 0, level: -25, attack: 0.02, release: 0.4, swell: -11, brightness: 1000)
    static let slideChord = SoundCueSheet.Chord(notes: [50, 57, 64, 66, 69], bass: 38, start: 0, end: 0, level: -34, attack: 0.5, release: 0.6, swell: -2, brightness: 1100)
    static let lineChord = SoundCueSheet.Chord(notes: [47, 54, 57, 62, 66], bass: 35, start: 0, end: 0, level: -38, attack: 0.5, release: 0.6, brightness: 1100)
    static let logoChord = SoundCueSheet.Chord(notes: [45, 52, 59, 61, 64], bass: 33, start: 0, end: 0, level: -44, attack: 0.6, release: 0.01, swell: -4, brightness: 1000)

    /// Each step's chord comes in this long before it shows.
    static let stepLead = 0.05

    /// The arpeggio under the words: four felt notes a word, its first on the word's frame, then a note
    /// every 0.105 s until the lockup settles; the IV figures, then I's from the slide.
    static let arpeggio = (
        words: [[74.0, 67, 71, 69], [74.0, 66, 69, 71]], slide: [[74.0, 69, 66, 64], [74.0, 66, 69, 76]],
        after: 0.105, accent: -19.0, level: -24.0, jitter: 1.0, pan: 0.25, send: 0.35, length: 0.9
    )

    /// It thins out 3 dB by the last word, then to −12 dB by the time the lockup settles.
    static let arpeggioFade = (lastWord: -3.0, settled: -12.0)

    /// A felt chord, rolled, at the dimmed line and, quieter, at the logo: the logo is the quietest moment.
    static let lineFelt = (notes: [71.0, 74, 78], roll: 0.02, level: -30.0, pans: [-0.2, 0, 0.2], length: 2.2, send: 0.45)
    static let logoFelt = (notes: [69.0, 76, 81, 85], roll: 0.025, level: -37.0, pans: [-0.25, -0.08, 0.08, 0.25], length: 2.8, send: 0.5)

    // MARK: - 5. Times land on frames

    /// The frame that first shows `time`: ⌈t·fps⌉/fps.
    static func frame(_ time: Double, frameRate: Int) -> Double {
        let rate = Double(frameRate)
        return (time * rate - 1e-6).rounded(.up) / rate
    }
}
