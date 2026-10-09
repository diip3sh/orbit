//
//  SoundCue.swift
//  Reco
//

import Foundation

/// One sound of a video's score or effects (spec 0013): what voice, the moment it marks, how loud, where
/// in the stereo field and how much of it goes to the room.
nonisolated struct SoundCue: Codable, Equatable, Sendable {

    /// The voices, each after the hand-made Supabase film's (`score.py`, round 6).
    nonisolated enum Voice: Codable, Hashable, Sendable {
        /// A struck glass: near-harmonic partials, the high ones dying first; `brightness` scales them.
        case glass(note: Double, length: Double, brightness: Double)

        /// A felt-hammered note: no click as it starts, its overtones gone before it.
        case felt(note: Double, length: Double)

        /// A soft pop: a tone sliding up 10 % into its note.
        case blip(note: Double, length: Double)

        /// A low hit: a sine sliding from `high` Hz down to `low`, with its second harmonic.
        case thump(high: Double, low: Double, length: Double, decay: Double)

        /// A keyboard key: the press's click and body, its release a moment later.
        case key(Key)

        /// Air rushing into the moment it marks, ending on it.
        case swish(length: Double)

        /// A whip's rush: noise swept up to the camera's fastest moment, which it marks, and gone as it lands.
        case whoosh

        /// Noise swept up from `low` Hz to `high`, rising into the moment it marks.
        case riser(length: Double, low: Double, high: Double, power: Double)

        // A beat score's (spec 0015)

        /// A drum, each hit drawn afresh from its seed.
        case drum(Drum)

        /// A sub bass note, an 808's: gliding onto `note` from the note `from`, or dropping onto it from 2 semitones up.
        case sub(note: Double, from: Double?, length: Double)

        /// House's plucked bass: a short saw over its own sub.
        case bass(note: Double, length: Double)

        /// A chord of plucked saws whose highs die first, as a closing filter would: house's stab.
        case stab(notes: [Double], length: Double)

        /// A chord on an electric piano: two-operator FM, its brightness dying with the note.
        case keys(notes: [Double], length: Double)

        /// A sung "ah" sliding from one note to another, then held with vibrato.
        case vox(from: Double, onto: Double, length: Double)

        // A story film's (spec 0015)

        /// A dither seam's dots: tiny square blips across the stereo field, swelling and thinning over its length.
        case bits(length: Double)
    }

    nonisolated enum Key: String, Codable, Hashable, Sendable {
        case letter, space, arrow, enter
    }

    nonisolated enum Drum: String, Codable, Hashable, Sendable {
        /// Drum and bass's: tight, its pitch dropping fast. House's: rounder, longer.
        case kick, houseKick
        case snare, clap
        /// Closed and open.
        case hat, openHat
        case crash
    }

    /// Which of the document's switches and levels it follows (``MotionSound``).
    nonisolated enum Part: String, Codable, Sendable {
        case score, effects
    }

    var voice: Voice
    var part: Part

    /// The moment it marks, on the frame that shows it, in seconds into the video.
    var time: Double

    /// How long after that it sounds: a later note of a rolled chord or of an arpeggio's bar.
    var offset = 0.0

    /// Its peak in dB.
    var level: Double

    /// −1 (left) to 1 (right).
    var pan = 0.0

    /// The share of it sent to the room.
    var send = 0.15

    /// What its noise and variation are drawn from.
    var seed: UInt64 = 0

    /// When it starts sounding, in seconds into the video.
    var start: Double {
        time + offset - lead
    }

    /// How long before its moment it starts: a swish, whoosh or riser leads into it.
    var lead: Double {
        switch voice {
        case .swish(let length): length
        case .whoosh: Self.whooshRise
        case .riser(let length, _, _, _): length
        default: 0
        }
    }

    /// A whoosh rises this long to its peak, then dies within 0.2 s, as the whip lands.
    static let whooshRise = 0.42
    static let whooshFall = 0.2
}
