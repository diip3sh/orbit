//
//  CompositionBuilder.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation

/// Builds what the player plays and export writes: the recording's kept ranges, drawn by
/// ``EditorCompositor`` with a render plan and mixed with the project's audio settings.
enum CompositionBuilder {

    /// How long audio fades out before a cut and back in after it, so the cut doesn't click.
    /// The mix lags its volume ramps by about 10 ms: measured at a cut, 10 ms ramps still left 57%
    /// of the volume, 20 ms 20%, and 25 ms 2%.
    nonisolated static let fadeDuration = 0.025

    /// The background music fades in over this long and out over ``backgroundFadeOut``, each at most a quarter of the
    /// output. Chosen 2026-10-08, not yet checked by ear: a longer end reads as a song ending, a shorter one as a cut.
    nonisolated static let backgroundFadeIn = 1.0
    nonisolated static let backgroundFadeOut = 2.0

    /// Every part, for a new player item or an export.
    static func composition(
        for source: EditorSource, plan: RenderPlan, audio: AudioMixSettings, extra: ExtraAudio = ExtraAudio()
    ) async throws -> EditorComposition {
        EditorComposition(
            asset: try await asset(for: source, timeMap: plan.timeMap, extra: extra),
            videoComposition: videoComposition(for: source, plan: plan),
            audioMix: audioMix(for: source, timeMap: plan.timeMap, settings: audio, extra: extra),
            extraAudio: extra
        )
    }

    /// Frames drawn with `plan`, at `frameRate` or the recording's.
    static func videoComposition(for source: EditorSource, plan: RenderPlan, frameRate: Double? = nil) -> AVVideoComposition {
        let duration = pieces(of: plan.timeMap, in: source).reduce(.zero) { $0 + $1.duration }
        let composition = AVMutableVideoComposition()
        composition.customVideoCompositorClass = plan.dynamicRange == .sdr ? EditorCompositor.self : HDREditorCompositor.self
        if let transferFunction = plan.dynamicRange.transferFunction {
            composition.colorPrimaries = AVVideoColorPrimaries_ITU_R_2020
            composition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_2020
            composition.colorTransferFunction = transferFunction
        }
        composition.renderSize = plan.canvas.size
        composition.frameDuration = CMTime(seconds: 1 / (frameRate ?? source.frameRate), preferredTimescale: source.timescale)
        composition.instructions = [
            EditorInstruction(timeRange: CMTimeRange(start: .zero, duration: duration), sourceTrackID: source.videoTrackID, plan: plan)
        ]
        return composition
    }

    /// Each audio track at its volume, and the click sounds at theirs, faded at every cut. The background music
    /// runs through the cuts, fading only at the ends of the output.
    static func audioMix(for source: EditorSource, timeMap: TimeMap, settings: AudioMixSettings, extra: ExtraAudio = ExtraAudio()) -> AVAudioMix {
        let fades = audioFades(for: timeMap)
        var parameters = source.audioTrackIDs.indices.map { index in
            inputParameters(trackID: source.audioTrackIDs[index], volume: settings[track: index].effectiveVolume, fades: fades)
        }
        if extra.clicks != nil {
            parameters.append(inputParameters(trackID: extraTrackID(1, for: source), volume: Float(settings.clickVolume), fades: fades))
        }
        if extra.background != nil, let background = settings.background {
            let ends = backgroundFades(outputDuration: timeMap.outputDuration)
            let volume = background.track.effectiveVolume
            let music = AVMutableAudioMixInputParameters()
            music.trackID = extraTrackID(2, for: source)
            music.setVolumeRamp(fromStartVolume: 0, toEndVolume: volume, timeRange: timeRange(ends.in))
            music.setVolumeRamp(fromStartVolume: volume, toEndVolume: 0, timeRange: timeRange(ends.out))
            parameters.append(music)
        }
        let mix = AVMutableAudioMix()
        mix.inputParameters = parameters
        return mix
    }

    /// The fade-in and fade-out of the background music, in output seconds. Each is at most a quarter of the output,
    /// so a short one still has a middle.
    nonisolated static func backgroundFades(outputDuration: Double) -> (in: Range<Double>, out: Range<Double>) {
        let fadeIn = min(backgroundFadeIn, outputDuration / 4)
        let fadeOut = min(backgroundFadeOut, outputDuration / 4)
        return (0..<fadeIn, outputDuration - fadeOut..<outputDuration)
    }

    /// Where a `length` long file starts when looped to fill `duration` from the start, and how much of it plays: the
    /// last copy is cut at the end. In `CMTime`, so the copies meet with no gap or overlap and the end is exact.
    nonisolated static func loopRanges(length: CMTime, filling duration: CMTime) -> [CMTimeRange] {
        guard length > .zero, duration > .zero else { return [] }
        var ranges: [CMTimeRange] = []
        var start = CMTime.zero
        while start < duration {
            ranges.append(CMTimeRange(start: start, duration: min(length, CMTimeSubtract(duration, start))))
            start = CMTimeAdd(start, length)
        }
        return ranges
    }

    /// Where audio fades, in output seconds: out at the end of each kept range a cut follows, and
    /// back in at the start of each one a cut precedes. A short range fades over half its length.
    nonisolated static func audioFades(for timeMap: TimeMap) -> [(range: Range<Double>, fadesIn: Bool)] {
        timeMap.keptRanges.flatMap { range in
            let start = timeMap.outputTime(atSource: range.lowerBound)
            let end = timeMap.outputTime(atSource: range.upperBound)
            let fade = min(fadeDuration, (end - start) / 2)
            var fades: [(range: Range<Double>, fadesIn: Bool)] = []
            if range.lowerBound > 0 {
                fades.append((start..<start + fade, true))
            }
            if range.upperBound < timeMap.sourceDuration {
                fades.append((end - fade..<end, false))
            }
            return fades
        }
    }

    // MARK: - Private

    /// The recording's video and audio tracks, with only the kept ranges at their speeds, under their own
    /// track IDs so the video composition and the mix can name them, then the extra audio the same way.
    private static func asset(for source: EditorSource, timeMap: TimeMap, extra: ExtraAudio) async throws -> AVComposition {
        let composition = AVMutableComposition()
        let pieces = pieces(of: timeMap, in: source)
        for track in try await source.asset.loadTracks(withMediaType: .video) {
            try insert(track, as: track.trackID, pieces: pieces, into: composition)
        }
        for track in try await source.asset.loadTracks(withMediaType: .audio) {
            let fast = await fastParts(of: track.trackID, pieces: pieces, files: extra.fastParts)
            try withExtendedLifetime(fast) {
                try insert(track, as: track.trackID, pieces: pieces, fastParts: fast, into: composition)
            }
        }
        // Optional, so a click file that went missing leaves the recording as it is; the mix names a track that isn't there
        if let clicks = extra.clicks {
            let clickAsset = AVURLAsset(url: clicks)
            if let track = try? await clickAsset.loadTracks(withMediaType: .audio).first {
                let trackID = extraTrackID(1, for: source)
                let fast = await fastParts(of: trackID, pieces: pieces, files: extra.fastParts)
                // A track holds its asset weakly: released before the insert, it failed with -12780
                try withExtendedLifetime((clickAsset, fast)) {
                    // ponytail: on the source timeline, so a fast part time-stretches its clicks too
                    try insert(track, as: trackID, pieces: pieces, fastParts: fast, into: composition)
                }
            }
        }
        if let background = extra.background {
            let output = pieces.reduce(CMTime.zero) { CMTimeAdd($0, $1.duration) }
            try await insertBackground(background, as: extraTrackID(2, for: source), filling: output, into: composition)
        }
        return composition
    }

    /// The music at `url`, repeated from the start of the output to exactly its end: longer than the video's, the
    /// compositor would draw black frames past it. Left out when the file has no audio any more.
    private static func insertBackground(
        _ url: URL, as trackID: CMPersistentTrackID, filling output: CMTime, into composition: AVMutableComposition
    ) async throws {
        let music = AVURLAsset(url: url)
        guard let track = try? await music.loadTracks(withMediaType: .audio).first,
              let compositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: trackID) else {
            return
        }
        let musicRange = try await track.load(.timeRange)
        // ponytail: a file that doesn't loop cleanly clicks at the seam; a crossfade needs two alternating tracks
        // A track holds its asset weakly, as with the click sounds
        try withExtendedLifetime(music) {
            for loop in loopRanges(length: musicRange.duration, filling: output) {
                let part = CMTimeRange(start: musicRange.start, duration: loop.duration)
                try compositionTrack.insertTimeRange(part, of: track, at: loop.start)
            }
        }
    }

    /// `track`'s `pieces`, end to end, each lasting its output length, as a new track of `composition` with ID `trackID`.
    /// Video is scaled; audio at another speed comes from its sped-up file in `fastParts` (by piece), silent without
    /// one, since a scaled audio edit exports at the wrong length (see ``SpeedAudio``).
    private static func insert(
        _ track: AVAssetTrack, as trackID: CMPersistentTrackID, pieces: [Piece], fastParts: [Int: FastPart] = [:],
        into composition: AVMutableComposition
    ) throws {
        guard let compositionTrack = composition.addMutableTrack(withMediaType: track.mediaType, preferredTrackID: trackID) else {
            throw AVError(.unknown)
        }
        var cursor = CMTime.zero
        for (index, piece) in pieces.enumerated() {
            if piece.duration == piece.source.duration {
                try compositionTrack.insertTimeRange(piece.source, of: track, at: cursor)
            } else if track.mediaType == .video {
                try compositionTrack.insertTimeRange(piece.source, of: track, at: cursor)
                compositionTrack.scaleTimeRange(CMTimeRange(start: cursor, duration: piece.source.duration), toDuration: piece.duration)
            } else if let fast = fastParts[index] {
                let range = CMTimeRange(start: fast.range.start, duration: CMTimeMinimum(piece.duration, fast.range.duration))
                try compositionTrack.insertTimeRange(range, of: fast.track, at: cursor)
            } else {
                compositionTrack.insertEmptyTimeRange(CMTimeRange(start: cursor, duration: piece.duration))
            }
            cursor = CMTimeAdd(cursor, piece.duration)
        }
    }

    /// A sped-up file's track, with its asset, which the composition holds only weakly.
    private struct FastPart {
        let asset: AVURLAsset
        let track: AVAssetTrack
        let range: CMTimeRange
    }

    /// The sped-up files of track `trackID`'s pieces at another speed, by piece; a piece whose file is missing or
    /// unreadable is left out.
    private static func fastParts(of trackID: CMPersistentTrackID, pieces: [Piece], files: [SpeedAudio.Part: URL]) async -> [Int: FastPart] {
        var parts: [Int: FastPart] = [:]
        for (index, piece) in pieces.enumerated() where piece.speed.rate != 1 {
            guard let url = files[SpeedAudio.Part(trackID: trackID, range: piece.speed.range, rate: piece.speed.rate)] else { continue }
            let asset = AVURLAsset(url: url)
            guard let track = try? await asset.loadTracks(withMediaType: .audio).first, let range = try? await track.load(.timeRange) else {
                continue
            }
            parts[index] = FastPart(asset: asset, track: track, range: range)
        }
        return parts
    }

    /// The ID of extra track `number` (from 1), above the recording's own so the mix can name it without loading it.
    static func extraTrackID(_ number: Int, for source: EditorSource) -> CMPersistentTrackID {
        ((source.audioTrackIDs + [source.videoTrackID]).max() ?? source.videoTrackID) + CMPersistentTrackID(number)
    }

    /// `volume` from the start, ramped to nothing and back at each of `fades`.
    private static func inputParameters(
        trackID: CMPersistentTrackID, volume: Float, fades: [(range: Range<Double>, fadesIn: Bool)]
    ) -> AVMutableAudioMixInputParameters {
        let parameters = AVMutableAudioMixInputParameters()
        parameters.trackID = trackID
        parameters.setVolume(volume, at: .zero)
        for fade in fades {
            parameters.setVolumeRamp(
                fromStartVolume: fade.fadesIn ? 0 : volume, toEndVolume: fade.fadesIn ? volume : 0, timeRange: timeRange(fade.range)
            )
        }
        return parameters
    }

    /// `range`, in output seconds, as a time range.
    private static func timeRange(_ range: Range<Double>) -> CMTimeRange {
        CMTimeRange(
            start: CMTime(seconds: range.lowerBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            end: CMTime(seconds: range.upperBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        )
    }

    /// A part of the recording and how long it lasts in the output.
    private struct Piece {
        let source: CMTimeRange
        let duration: CMTime
        let speed: SpeedRange
    }

    /// The time map's pieces in the recording's time scale, the last ending where the recording does. A piece
    /// at another speed lasts its length over its rate, to the nanosecond: rounded to the recording's time scale,
    /// the error would add up over many pieces and move the frames against the overlays.
    private static func pieces(of timeMap: TimeMap, in source: EditorSource) -> [Piece] {
        timeMap.pieces.map { piece in
            let end = piece.range.upperBound < timeMap.sourceDuration
                ? CMTime(seconds: piece.range.upperBound, preferredTimescale: source.timescale)
                : source.timeRange.end
            let range = CMTimeRange(start: CMTime(seconds: piece.range.lowerBound, preferredTimescale: source.timescale), end: end)
            let duration = piece.rate == 1
                ? range.duration
                : CMTime(seconds: range.duration.seconds / piece.rate, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            return Piece(source: range, duration: duration, speed: piece)
        }
    }
}
