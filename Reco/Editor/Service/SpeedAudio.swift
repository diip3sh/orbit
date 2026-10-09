//
//  SpeedAudio.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import AVFoundation

/// The audio of the parts at another speed, sped up with its pitch kept, as files the composition inserts as they are.
///
/// The composition can't scale its audio itself: `AVAssetReaderAudioMixOutput`, which the export reads the mix through,
/// applies a scaled edit's rate change only after it has converted past it ("scheduling rate change at unscaled t=9600,
/// but we previously did a conversion for t=13056"), with every pitch algorithm. Measured 2026-10-08: a second of audio
/// with 0.2–0.6 s at 4× (0.7 s of output) mixed to 0.709–0.808 s across runs, and exported at 0.775 s.
nonisolated enum SpeedAudio {

    /// One track's part at one rate, which names its file.
    struct Part: Hashable, Sendable {
        /// The composition's ID for the track: the recording's own, or the click sounds'.
        let trackID: CMPersistentTrackID

        /// Source seconds, as in ``TimeMap/pieces``.
        let range: Range<Double>

        let rate: Double
    }

    /// Where a window keeps its sped-up audio, until it closes.
    static var folder: URL {
        URL.temporaryDirectory.appending(path: "Reco Speed Audio")
    }

    /// Audio read past each end of a part, so the time-pitch overlaps real sound there and the part meets its
    /// neighbours without a dip.
    static let context = 0.25

    /// The parts of `timeMap` not at 1×, for each of `trackIDs`.
    static func parts(of timeMap: TimeMap, trackIDs: [CMPersistentTrackID]) -> [Part] {
        let pieces = timeMap.pieces.filter { $0.rate != 1 }
        return trackIDs.flatMap { trackID in pieces.map { Part(trackID: trackID, range: $0.range, rate: $0.rate) } }
    }

    /// Writes `part` of the audio track `trackID` (the first one when `nil`) of the file at `source`, on the source
    /// timeline, sped up to `url`: its length over its rate, rounded up to a whole frame, in Apple Lossless.
    @concurrent
    static func render(_ part: Part, from source: URL, trackID: CMPersistentTrackID?, to url: URL) async throws {
        let audio = try await OfflineAudioEffect.Source(trackID, of: source)
        let timescale = CMTimeScale(audio.format.sampleRate)
        let reader = try audio.reader(over: CMTimeRange(
            start: CMTime(seconds: max(part.range.lowerBound - context, audio.timeRange.start.seconds), preferredTimescale: timescale),
            end: CMTime(seconds: min(part.range.upperBound + context, audio.timeRange.end.seconds), preferredTimescale: timescale)
        ))
        defer { reader.cancelReading() }
        let timePitch = AVAudioUnitTimePitch()
        timePitch.rate = Float(part.rate)
        let frames = Int(((part.range.upperBound - part.range.lowerBound) / part.rate * audio.format.sampleRate).rounded(.up))
        try OfflineAudioEffect.write(to: url, format: audio.format) { file in
            try OfflineAudioEffect(format: audio.format, effect: timePitch)
                .process(reader.outputs[0], from: part.range.lowerBound, frames: frames, rate: part.rate, into: file)
        }
    }
}
