//
//  MotionCompositionBuilder.swift
//  Reco
//

import AVFoundation

/// Builds what the player plays and export writes for a motion video: frames drawn by
/// ``MotionCompositor``, driven by a placeholder movie.
///
/// A composition needs a video track with media: one that holds only an empty range reports a
/// duration of 0, and `AVAssetReaderVideoCompositionOutput` refuses it. A 1-frame 16×16 movie
/// stretched to the video's length drives preview, export and GIF alike (spec 0011, spike A).
enum MotionCompositionBuilder {

    static func composition(for plan: MotionPlan) async throws -> EditorComposition {
        let placeholder = AVURLAsset(url: try await placeholderMovie())
        guard let source = try await placeholder.loadTracks(withMediaType: .video).first else { throw AVError(.unknown) }
        let range = try await source.load(.timeRange)

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw AVError(.unknown)
        }
        try track.insertTimeRange(range, of: source, at: .zero)
        track.scaleTimeRange(CMTimeRange(start: .zero, duration: range.duration), toDuration: duration(of: plan))
        return EditorComposition(asset: composition, videoComposition: videoComposition(for: plan, placeholderTrackID: track.trackID), audioMix: AVMutableAudioMix())
    }

    /// Frames drawn with `plan` at its frame rate, tagged BT.709.
    static func videoComposition(for plan: MotionPlan, placeholderTrackID: CMPersistentTrackID) -> AVVideoComposition {
        let composition = AVMutableVideoComposition()
        composition.customVideoCompositorClass = MotionCompositor.self
        composition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
        composition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
        composition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
        composition.renderSize = plan.outputSize
        composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(plan.frameRate))
        composition.instructions = [
            MotionInstruction(timeRange: CMTimeRange(start: .zero, duration: duration(of: plan)), placeholderTrackID: placeholderTrackID, plan: plan)
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
