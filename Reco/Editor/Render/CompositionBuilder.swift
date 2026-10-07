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

    /// Each audio track at its volume, and the click sounds at theirs, faded at every cut.
    static func audioMix(for source: EditorSource, timeMap: TimeMap, settings: AudioMixSettings, extra: ExtraAudio = ExtraAudio()) -> AVAudioMix {
        let fades = audioFades(for: timeMap)
        var parameters = source.audioTrackIDs.indices.map { index in
            inputParameters(trackID: source.audioTrackIDs[index], volume: settings[track: index].effectiveVolume, fades: fades)
        }
        if extra.clicks != nil {
            parameters.append(inputParameters(trackID: extraTrackID(1, for: source), volume: Float(settings.clickVolume), fades: fades))
        }
        let mix = AVMutableAudioMix()
        mix.inputParameters = parameters
        return mix
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
        return composition
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
            let timeRange = CMTimeRange(
                start: CMTime(seconds: fade.range.lowerBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                end: CMTime(seconds: fade.range.upperBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            )
            parameters.setVolumeRamp(fromStartVolume: fade.fadesIn ? 0 : volume, toEndVolume: fade.fadesIn ? volume : 0, timeRange: timeRange)
        }
        return parameters
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
