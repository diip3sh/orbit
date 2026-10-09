//
//  SoundRules+Beat.swift
//  Reco
//

import Foundation

/// A beat score's numbers (spec 0015), each style's from its reference's soundtrack: Lovable's launch film for
/// ``groove``, LordyVisuals' Spotify Jam concept for ``house``. Patterns are two bars of sixteenths (steps 0–31).
nonisolated struct BeatStyle: Sendable {

    /// A hit in a two-bar phrase: its sixteenth and its level against its part's, in dB.
    nonisolated struct Hit: Sendable {
        let step: Int
        let level: Double

        init(_ step: Int, _ level: Double = 0) {
            (self.step, self.level) = (step, level)
        }
    }

    /// A bass note in a phrase: its sixteenth, semitones above the bar's bass note, and whether it slides there
    /// from the note before.
    nonisolated struct BassNote: Sendable {
        let step: Int
        let interval: Int
        let slides: Bool

        init(_ step: Int, _ interval: Int = 0, slides: Bool = false) {
            (self.step, self.interval, self.slides) = (step, interval, slides)
        }
    }

    /// A vocal chop in a phrase: its sixteenth, the chord's notes it slides between (indices from the lowest, an octave
    /// up) and how many sixteenths it lasts.
    nonisolated struct Chop: Sendable {
        let step: Int
        let from: Int
        let onto: Int
        let length: Int
    }

    /// The pad's brightness (Hz, ``SoundCueSheet/Chord/brightness``) in each part.
    nonisolated struct Brightness: Sendable {
        let intro, body, lift, outro: Double
    }

    /// A chord: MIDI notes, and the bass note under it.
    nonisolated struct Harmony: Equatable, Sendable {
        let notes: [Int]
        let bass: Int
    }

    /// Peak levels in dB before the master, pads as RMS: the balance the master lifts as a whole.
    nonisolated struct Levels: Sendable {
        let kick, snare, clap, hat, openHat, crash, bass, chords, pad, impact, riser: Double
    }

    /// Which voices play the chords and the bass: drum and bass's electric piano over an 808 sub, house's stabs over a
    /// plucked bass.
    nonisolated enum Voicing: Sendable {
        case keysAndSub, stabsAndPluck
    }

    let tempo: Double
    let kick: SoundCue.Drum
    let voicing: Voicing

    let kicks: [Hit]
    let snares: [Hit]
    let claps: [Hit]
    let hats: [Hit]
    let openHats: [Hit]
    let bassline: [BassNote]

    /// Where the keys or stabs strike in a phrase; the first a bar long, the rest short.
    let chordHits: [Hit]

    /// A voice chopped into short sung notes over the chords: the Spotify Jam's mid-range is full of them.
    let chops: [Chop]

    /// The body's chords, a bar each, from each drop.
    let progression: [Harmony]

    /// Before the drop, two bars each, counted back from it; empty when the drums play from the first beat.
    let intro: [Harmony]

    /// Under a break, a bar each.
    let lift: [Harmony]

    /// The outro holds the first and lands on the second with the last hit.
    let held: Harmony
    let home: Harmony

    /// The last beat before a drop, a return and every ``fillBars`` bars: four sixteenths rising.
    let fill: [Hit]
    let fillBars: Int

    let levels: Levels

    /// How deep the pad ducks on each beat.
    let pump: Double
    let brightness: Brightness

    var beat: Double {
        60 / tempo
    }
}

nonisolated extension SoundRules {

    // MARK: - The grid

    /// A cut lands on a beat within this: a frame at 30 fps is 33 ms, so 25 ms is as tight as cuts on frames allow.
    static let beatTolerance = 0.025

    /// How far the tempo moves from the style's to land more cuts on beats.
    static let tempoReach = 0.03

    /// The tempos tried, in BPM apart: 0.05 BPM drifts 13 ms over 45 s at 170 BPM.
    static let tempoStep = 0.05
    static let phaseStep = 0.001

    // MARK: - The form

    /// The drop is the first cut at least this many bars in (1.75: a cut a beat short of two bars still counts),
    /// up to ``latestDrop``; without one there, two bars from the first beat.
    static let earliestDrop = 1.75
    static let latestDrop = 4.5

    /// A break goes under a scene of words alone in the second half, the one nearest this share of the film (Lovable's
    /// at 33.5 s of 48.8, 69 %), at least ``shortestBreak`` beats long.
    static let breakPlace = 0.7
    static let shortestBreak = 3.0

    /// The outro is the trailing scenes of words or a logo, from at least this share of the film.
    static let outroFrom = 0.6

    /// The longest outro, in bars: Lovable's drums went out 5.2 s (3.7 bars) before its end.
    static let longestOutro = 4.0

    /// A logo: a drawn layer no bigger than this share of the canvas either way.
    static let logoShare = 0.25

    /// House dips for a beat before the cut nearest the film's middle, between these shares of it.
    static let dipWindow = 0.35...0.65

    // MARK: - The mix

    /// Effects sit this much lower under a beat, and a pop moves onto the nearest sixteenth within ``popSnap``.
    static let effectsUnderBeat = -6.0
    static let popSnap = 0.02

    /// Beat scores are mastered as their references were (Lovable −15.8, Spotify Jam −14.3 LUFS), true peaks under −1 dBTP.
    static let beatFinish = SoundCueSheet.Finish(loudness: -14, ceiling: -1)

    /// Hats move by up to this much in time and level, so no two bars are alike, and sit this far to either side.
    static let hatJitter = (time: 0.003, level: 1.5)
    static let hatPan = 0.45

    /// A riser into a drop or a return, at most this long.
    static let dropRiser = (length: 2.8, low: 300.0, high: 6000.0, power: 2.2)
    static let dropImpact = (high: 70.0, low: 36.0, length: 1.6, decay: 0.45)

    // MARK: - Styles

    /// Lovable's: 170 BPM (hats 0.176 s apart, rolls at 0.088 s, claps every 0.70–0.72 s on beats 2 and 4, bars of
    /// 1.41 s); an F♯m intro, then F♯ dominant (F♯7 add 9, Badd9, C♯m7 colours); a sub with downward glides on its hits;
    /// a pumping pad; 2.3–3.4 kHz centroid in the body.
    static let groove = BeatStyle(
        tempo: 170,
        kick: .kick,
        voicing: .keysAndSub,
        // Two-step: 1 and 3-and, a double on the second bar's 3-and
        kicks: [BeatStyle.Hit(0), BeatStyle.Hit(10), BeatStyle.Hit(16), BeatStyle.Hit(26), BeatStyle.Hit(27, -5)],
        snares: [BeatStyle.Hit(4), BeatStyle.Hit(7, -16), BeatStyle.Hit(12), BeatStyle.Hit(20), BeatStyle.Hit(23, -16), BeatStyle.Hit(28),
                 BeatStyle.Hit(31, -13)],
        claps: [BeatStyle.Hit(4), BeatStyle.Hit(12), BeatStyle.Hit(20), BeatStyle.Hit(28)],
        // Eighths, the offbeats up, sixteenths in pairs and rolling into each bar: the reference's hats are 0.176 s apart
        // with runs at 0.088 s (a median gap of 0.109 s)
        hats: stride(from: 0, to: 32, by: 2).map { BeatStyle.Hit($0, $0.isMultiple(of: 4) ? -4 : 0) }
            + [BeatStyle.Hit(5, -7), BeatStyle.Hit(11, -6), BeatStyle.Hit(13, -5), BeatStyle.Hit(15, -4), BeatStyle.Hit(21, -7),
               BeatStyle.Hit(27, -6), BeatStyle.Hit(29, -5), BeatStyle.Hit(31, -3)],
        openHats: [BeatStyle.Hit(30)],
        bassline: [BeatStyle.BassNote(0), BeatStyle.BassNote(10), BeatStyle.BassNote(16), BeatStyle.BassNote(26, 7, slides: true)],
        chordHits: [BeatStyle.Hit(0), BeatStyle.Hit(7, -5), BeatStyle.Hit(14, -4), BeatStyle.Hit(22, -5), BeatStyle.Hit(25, -6)],
        chops: [],
        progression: [
            BeatStyle.Harmony(notes: [54, 58, 61, 64, 68], bass: 30), BeatStyle.Harmony(notes: [54, 58, 61, 64, 68], bass: 30),
            BeatStyle.Harmony(notes: [59, 61, 63, 66], bass: 35), BeatStyle.Harmony(notes: [56, 59, 61, 64], bass: 37)
        ],
        // F♯m9, Dmaj9: the reference's intro reads F♯m with D
        intro: [BeatStyle.Harmony(notes: [54, 57, 61, 64, 68], bass: 30), BeatStyle.Harmony(notes: [50, 54, 57, 61, 64], bass: 26)],
        lift: [BeatStyle.Harmony(notes: [59, 61, 63, 66], bass: 35), BeatStyle.Harmony(notes: [56, 59, 61, 64], bass: 37)],
        held: BeatStyle.Harmony(notes: [59, 63, 66, 73], bass: 35),
        home: BeatStyle.Harmony(notes: [54, 61, 66, 68, 70], bass: 30),
        fill: [BeatStyle.Hit(12, -7), BeatStyle.Hit(13, -6), BeatStyle.Hit(14, -3), BeatStyle.Hit(15, -1)],
        fillBars: 4,
        // The pad 3 dB up and the hats 2: the groove had a third less of the reference's 250–500 Hz and half its air over 8 kHz
        levels: BeatStyle.Levels(kick: -5, snare: -12, clap: -14, hat: -12, openHat: -17, crash: -15, bass: -11.5, chords: -11, pad: -16,
                                 impact: -8, riser: -18),
        pump: 0.6,
        brightness: BeatStyle.Brightness(intro: 700, body: 1500, lift: 1900, outro: 1300)
    )

    /// The Spotify Jam's: 125 BPM house (a kick every 0.48 s from the first frame, hats on the offbeats), F♯add9 ↔ A♯m7
    /// with G♯m9 and D♯sus2 a bar (1.92 s) each, its bass around G♯2.
    static let house = BeatStyle(
        tempo: 125,
        kick: .houseKick,
        voicing: .stabsAndPluck,
        kicks: stride(from: 0, to: 32, by: 4).map { BeatStyle.Hit($0) },
        snares: [],
        claps: [BeatStyle.Hit(4), BeatStyle.Hit(12), BeatStyle.Hit(20), BeatStyle.Hit(28)],
        // Sixteenths, the ones between the eighths up; the offbeat eighth is the open hat's
        hats: (0..<32).map { BeatStyle.Hit($0, [-9, -5, -13, -5][$0 % 4]) },
        openHats: stride(from: 2, to: 32, by: 4).map { BeatStyle.Hit($0) },
        bassline: stride(from: 2, to: 32, by: 4).map { BeatStyle.BassNote($0, $0 == 14 ? 12 : $0 == 30 ? 7 : 0) },
        // On the offbeats with the bass and the open hat, the last pushed a sixteenth early
        chordHits: [BeatStyle.Hit(2), BeatStyle.Hit(6, -2), BeatStyle.Hit(10, -1), BeatStyle.Hit(14, -2), BeatStyle.Hit(18, -1),
                    BeatStyle.Hit(22, -2), BeatStyle.Hit(25, -1), BeatStyle.Hit(30, -3)],
        // A call and its answer: up the chord, then sliding down it
        chops: [BeatStyle.Chop(step: 3, from: 3, onto: 3, length: 2), BeatStyle.Chop(step: 6, from: 2, onto: 3, length: 3),
                BeatStyle.Chop(step: 11, from: 3, onto: 2, length: 4), BeatStyle.Chop(step: 19, from: 2, onto: 2, length: 2),
                BeatStyle.Chop(step: 22, from: 1, onto: 2, length: 3), BeatStyle.Chop(step: 27, from: 3, onto: 1, length: 5)],
        progression: [
            BeatStyle.Harmony(notes: [54, 58, 61, 68], bass: 42), BeatStyle.Harmony(notes: [56, 58, 61, 65], bass: 46),
            BeatStyle.Harmony(notes: [56, 59, 63, 66], bass: 44), BeatStyle.Harmony(notes: [51, 53, 58, 63], bass: 39)
        ],
        intro: [],
        lift: [BeatStyle.Harmony(notes: [56, 59, 63, 66], bass: 44)],
        held: BeatStyle.Harmony(notes: [56, 59, 63, 66], bass: 44),
        home: BeatStyle.Harmony(notes: [54, 58, 61, 68], bass: 42),
        fill: [BeatStyle.Hit(12, -7), BeatStyle.Hit(13, -5), BeatStyle.Hit(14, -3), BeatStyle.Hit(15, -1)],
        fillBars: 8,
        levels: BeatStyle.Levels(kick: -6, snare: -9, clap: -10, hat: -15, openHat: -13, crash: -15, bass: -16, chords: -8, pad: -17,
                                 impact: -10, riser: -18),
        pump: 0.7,
        brightness: BeatStyle.Brightness(intro: 1200, body: 1400, lift: 1800, outro: 1400)
    )

    static func beat(_ style: MotionSound.Style) -> BeatStyle? {
        switch style {
        case .ambient: nil
        case .groove: groove
        case .house: house
        }
    }
}
