//
//  ScoreRenderer.swift
//  Reco
//

import Accelerate
import OSLog

/// Makes a cue sheet's sound (spec 0013): every chord and cue placed dry and sent to the room, the room
/// mixed under them, then mastered. Pure and seeded, so a sheet always gives the same samples.
nonisolated enum ScoreRenderer {

    /// How much of a chord goes to the room: the pads sit further back than the effects.
    static let padSend: Float = 0.35

    private static let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "ScoreRenderer")

    static func render(_ sheet: SoundCueSheet) -> StereoSound {
        let signpost = signposter.beginInterval("Render")
        defer { signposter.endInterval("Render", signpost) }
        let count = SoundSignal.count(sheet.length)
        var mix = Mix(dry: StereoSound(silence: count), send: StereoSound(silence: count))
        for (index, chord) in sheet.chords.enumerated() {
            mix.place(.stereo(SoundVoices.pad(chord, seed: 0xC40D_0000 &+ UInt64(index))), at: chord.start, level: chord.level, send: padSend)
        }
        if let air = sheet.air {
            mix.place(.stereo(SoundVoices.air(air, seed: 0xA112)), at: air.start, level: air.level, send: 0)
        }
        for cue in sheet.cues {
            mix.place(SoundVoices.sound(of: cue), at: cue.start, level: cue.level, pan: cue.pan, send: Float(cue.send))
        }
        let wet = SoundRoom.wet(mix.send, stop: sheet.roomStop.map(SoundSignal.count))
        let room = StereoSound(left: vDSP.add(multiplication: (wet.left, SoundRoom.level), mix.dry.left),
                               right: vDSP.add(multiplication: (wet.right, SoundRoom.level), mix.dry.right))
        return SoundFinish.finished(room)
    }

    /// The dry sound and what's sent to the room, built up cue by cue.
    private struct Mix {
        var dry: StereoSound
        var send: StereoSound

        /// Adds `sound` from `time` seconds at `level` dB; a mono sound panned at equal power.
        mutating func place(_ sound: SoundVoices.Sound, at time: Double, level: Double, pan: Double = 0, send share: Float) {
            let gain = Float(SoundSignal.gain(level))
            let offset = Int((time * SoundSignal.sampleRate).rounded())
            let channels: (left: [Float], right: [Float])
            var gains: (left: Float, right: Float)
            switch sound {
            case .mono(let samples):
                let angle = (pan + 1) * .pi / 4
                channels = (samples, samples)
                gains = (gain * Float(cos(angle) * 2.0.squareRoot()), gain * Float(sin(angle) * 2.0.squareRoot()))
            case .stereo(let stereo):
                channels = (stereo.left, stereo.right)
                gains = (gain, gain)
            }
            dry.add(channels, gains: gains, at: offset)
            guard share > 0 else { return }
            gains = (gains.left * share, gains.right * share)
            send.add(channels, gains: gains, at: offset)
        }
    }
}
