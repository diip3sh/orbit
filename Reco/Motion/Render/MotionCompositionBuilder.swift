//
//  MotionCompositionBuilder.swift
//  Reco
//

import AVFoundation

/// Builds what the player plays and export writes for a motion video: frames drawn by
/// ``MotionCompositor``, driven by a placeholder movie, with a track for each live layer's take and
/// one for its sound.
///
/// A composition needs a video track with media: one that holds only an empty range reports a
/// duration of 0, and `AVAssetReaderVideoCompositionOutput` refuses it. A 1-frame 16×16 movie
/// stretched to the video's length drives preview, export and GIF alike (spec 0011, spike A).
enum MotionCompositionBuilder {

    /// - Parameter sound: The video's sound (``SoundCache``), played from its start; `nil` for none.
    static func composition(for plan: MotionPlan, sound: URL? = nil) async throws -> EditorComposition {
        let placeholder = AVURLAsset(url: try await placeholderMovie())
        guard let source = try await placeholder.loadTracks(withMediaType: .video).first else { throw AVError(.unknown) }
        let range = try await source.load(.timeRange)

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw AVError(.unknown)
        }
        try track.insertTimeRange(range, of: source, at: .zero)
        track.scaleTimeRange(CMTimeRange(start: .zero, duration: range.duration), toDuration: duration(of: plan))
        var liveTracks: [MotionPlan.LayerKey: CMPersistentTrackID] = [:]
        for layer in plan.liveLayers {
            liveTracks[layer.key] = try await add(layer, to: composition)
        }
        if let sound {
            try await add(sound, to: composition, length: duration(of: plan))
        }
        return EditorComposition(
            asset: composition, videoComposition: videoComposition(for: plan, placeholderTrackID: track.trackID, liveTracks: liveTracks),
            audioMix: AVMutableAudioMix()
        )
    }

    /// Plays the layer's take from its scene's start to its end, holding the last frame when the
    /// scene is longer, and returns its track.
    private static func add(_ layer: MotionPlan.LiveLayer, to composition: AVMutableComposition) async throws -> CMPersistentTrackID {
        // Kept: a track holds its asset weakly, and inserting a track whose asset is gone fails (-12780)
        let movie = AVURLAsset(url: layer.live.movie)
        guard let source = try await movie.loadTracks(withMediaType: .video).first,
              let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw AVError(.unknown)
        }
        let take = try await source.load(.timeRange)
        let start = CMTime(seconds: layer.sceneStart, preferredTimescale: 60_000)
        let scene = CMTime(seconds: layer.sceneDuration, preferredTimescale: 60_000)
        let shown = CMTimeMinimum(take.duration, scene)
        try track.insertTimeRange(CMTimeRange(start: take.start, duration: shown), of: source, at: start)
        if take.duration < scene {
            // Takes are rendered at a constant frame rate
            let frame = CMTime(value: 1, timescale: CMTimeScale(WebScript.frameRate))
            let last = CMTimeRange(start: take.end - frame, duration: frame)
            try track.insertTimeRange(last, of: source, at: start + shown)
            track.scaleTimeRange(CMTimeRange(start: start + shown, duration: frame), toDuration: scene - shown)
        }
        return track.trackID
    }

    /// Plays `sound` from the video's start, cut where the video ends.
    private static func add(_ sound: URL, to composition: AVMutableComposition, length: CMTime) async throws {
        // Kept until inserted: a track holds its asset weakly
        let asset = AVURLAsset(url: sound)
        guard let source = try await asset.loadTracks(withMediaType: .audio).first,
              let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw AVError(.unknown)
        }
        let range = try await source.load(.timeRange)
        try track.insertTimeRange(CMTimeRange(start: range.start, duration: CMTimeMinimum(range.duration, length)), of: source, at: .zero)
    }

    /// Frames drawn with `plan` at its frame rate, tagged BT.709.
    static func videoComposition(
        for plan: MotionPlan, placeholderTrackID: CMPersistentTrackID, liveTracks: [MotionPlan.LayerKey: CMPersistentTrackID] = [:]
    ) -> AVVideoComposition {
        let composition = AVMutableVideoComposition()
        composition.customVideoCompositorClass = MotionCompositor.self
        composition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
        composition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
        composition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
        composition.renderSize = plan.outputSize
        composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(plan.frameRate))
        composition.instructions = [
            MotionInstruction(
                timeRange: CMTimeRange(start: .zero, duration: duration(of: plan)), placeholderTrackID: placeholderTrackID, liveTracks: liveTracks, plan: plan
            )
        ]
        return composition
    }

    /// Whole frames, so the last one is drawn in full.
    private static func duration(of plan: MotionPlan) -> CMTime {
        CMTime(value: CMTimeValue(plan.frameCount), timescale: CMTimeScale(plan.frameRate))
    }

    /// The placeholder, written once per launch into the temporary folder (0.12 s, spike A).
    @concurrent
    nonisolated private static func placeholderMovie() async throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "Reco-motion-placeholder.mov")
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            return url
        }
        // Written beside it and moved into place, so two builds at once never read half a file
        let partial = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: partial) }
        let writer = try AVAssetWriter(outputURL: partial, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 16, AVVideoHeightKey: 16])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 16, 16, kCVPixelFormatType_32BGRA, nil, &buffer)
        guard let buffer, writer.startWriting() else { throw writer.error ?? AVError(.unknown) }
        writer.startSession(atSourceTime: .zero)
        CVPixelBufferLockBaseAddress(buffer, [])
        memset(CVPixelBufferGetBaseAddress(buffer), 0, CVPixelBufferGetDataSize(buffer))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        adaptor.append(buffer, withPresentationTime: .zero)
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: 1, timescale: 30))
        await writer.finishWritingWithoutAsyncImport()
        guard writer.status == .completed else { throw writer.error ?? AVError(.unknown) }
        // Another build may have moved its copy into place meanwhile
        try? FileManager.default.moveItem(at: partial, to: url)
        return url
    }
}
