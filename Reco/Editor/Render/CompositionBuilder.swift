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
        let duration = timeRanges(of: plan.timeMap, in: source).reduce(.zero) { $0 + $1.duration }
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
            let end = start + range.upperBound - range.lowerBound
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

    /// The recording's video and audio tracks, with only the kept ranges, under their own track
    /// IDs so the video composition and the mix can name them, then the extra audio the same way.
    private static func asset(for source: EditorSource, timeMap: TimeMap, extra: ExtraAudio) async throws -> AVComposition {
        let composition = AVMutableComposition()
        let ranges = timeRanges(of: timeMap, in: source)
        for mediaType in [AVMediaType.video, .audio] {
            for track in try await source.asset.loadTracks(withMediaType: mediaType) {
                try insert(track, as: track.trackID, ranges: ranges, into: composition)
            }
        }
        // Optional, so a click file that went missing leaves the recording as it is; the mix names a track that isn't there
        if let clicks = extra.clicks {
            let clickAsset = AVURLAsset(url: clicks)
            if let track = try? await clickAsset.loadTracks(withMediaType: .audio).first {
                // A track holds its asset weakly: released before the insert, it failed with -12780
                try withExtendedLifetime(clickAsset) {
                    try insert(track, as: extraTrackID(1, for: source), ranges: ranges, into: composition)
                }
            }
        }
        if let background = extra.background {
            try await insertBackground(background, as: extraTrackID(2, for: source), filling: ranges, into: composition)
        }
        return composition
    }

    /// The music at `url`, repeated from the start of the output to exactly its end: longer than the video's, the
    /// compositor would draw black frames past it. Left out when the file has no audio any more.
    private static func insertBackground(
        _ url: URL, as trackID: CMPersistentTrackID, filling ranges: [CMTimeRange], into composition: AVMutableComposition
    ) async throws {
        let music = AVURLAsset(url: url)
        guard let track = try? await music.loadTracks(withMediaType: .audio).first,
              let compositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: trackID) else {
            return
        }
        let output = ranges.reduce(CMTime.zero) { CMTimeAdd($0, $1.duration) }
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

    /// `track`'s `ranges`, end to end, as a new track of `composition` with ID `trackID`.
    private static func insert(_ track: AVAssetTrack, as trackID: CMPersistentTrackID, ranges: [CMTimeRange], into composition: AVMutableComposition) throws {
        guard let compositionTrack = composition.addMutableTrack(withMediaType: track.mediaType, preferredTrackID: trackID) else {
            throw AVError(.unknown)
        }
        var cursor = CMTime.zero
        for range in ranges {
            try compositionTrack.insertTimeRange(range, of: track, at: cursor)
            cursor = CMTimeAdd(cursor, range.duration)
        }
    }

    /// The ID of extra track `number` (from 1), above the recording's own so the mix can name it without loading it.
    private static func extraTrackID(_ number: Int, for source: EditorSource) -> CMPersistentTrackID {
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

    /// The kept ranges in the recording's time scale. The last one ends where the recording does.
    private static func timeRanges(of timeMap: TimeMap, in source: EditorSource) -> [CMTimeRange] {
        timeMap.keptRanges.map { range in
            let end = range.upperBound < timeMap.sourceDuration
                ? CMTime(seconds: range.upperBound, preferredTimescale: source.timescale)
                : source.timeRange.end
            return CMTimeRange(start: CMTime(seconds: range.lowerBound, preferredTimescale: source.timescale), end: end)
        }
    }
}
