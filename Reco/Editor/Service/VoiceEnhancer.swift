//
//  VoiceEnhancer.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import AVFoundation

/// A microphone track with the voice isolated from the noise around it, as a file the composition plays in the
/// track's place.
///
/// The system's `AUSoundIsolation` (the one behind Voice Isolation in FaceTime), run offline over the whole track once.
/// Not voice processing I/O: that is live-only echo cancellation, and it lowers other apps' audio.
nonisolated enum VoiceEnhancer {

    /// Where a window keeps its enhanced tracks, until it closes.
    static var folder: URL {
        URL.temporaryDirectory.appending(path: "Reco Enhanced Voice")
    }

    /// How long the sound isolation delays audio of `channels` channels, which it reports as 0. Measured 2026-10-08
    /// (macOS 27.0.1, M2) by correlating 7 s of enhanced speech with the speech, the same through the file and across
    /// runs: mono 4440 frames at 48 kHz and 4083 at 44.1 kHz; stereo 1920 and 1768 more. The test checks both.
    static func latency(channels: UInt32) -> Double {
        channels == 1 ? 0.0925 : 0.1325
    }

    /// Writes audio track `trackID` of the file at `source`, with its voice isolated, to `url`: on the source
    /// timeline from 0 (silent before the track's first sample), as long as the track to the frame, in Apple Lossless.
    @concurrent
    static func render(trackID: CMPersistentTrackID, from source: URL, to url: URL) async throws {
        let audio = try await OfflineAudioEffect.Source(trackID, of: source)
        let reader = try audio.reader(over: audio.timeRange)
        defer { reader.cancelReading() }
        let frames = Int((audio.timeRange.end.seconds * audio.format.sampleRate).rounded())
        try OfflineAudioEffect.write(to: url, format: audio.format) { file in
            try OfflineAudioEffect(format: audio.format, effect: soundIsolation(), latency: latency(channels: audio.format.channelCount))
                .process(reader.outputs[0], from: 0, frames: frames, rate: 1, into: file)
        }
    }

    /// The sound isolation unit set to keep voices. Measured for spec 0004 on noise alone: its RMS went from 0.0162
    /// to 0.0038 with this type and to 0.0005 with the plain Voice one, which takes more of the voice with it.
    private static func soundIsolation() -> AVAudioUnitEffect {
        let effect = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_AUSoundIsolation,
            componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0
        ))
        AudioUnitSetParameter(
            effect.audioUnit, AudioUnitParameterID(kAUSoundIsolationParam_SoundToIsolate), kAudioUnitScope_Global, 0,
            AudioUnitParameterValue(kAUSoundIsolationSoundType_HighQualityVoice), 0
        )
        return effect
    }
}
