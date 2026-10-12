//
//  MovieEncoder.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import AVFoundation
import VideoToolbox

/// Writes a composition as an MP4 or ProRes movie with an `AVAssetReader` and an `AVAssetWriter`: the reader
/// draws the frames and mixes the audio, the writer encodes them. Presets can't set a bitrate or a ProRes
/// flavour, which is what the export page's quality levels are.
nonisolated enum MovieEncoder {

    /// One stream: what the reader gives and the writer takes.
    private struct Stream: @unchecked Sendable {
        let output: AVAssetReaderOutput
        let input: AVAssetWriterInput
        let isVideo: Bool
    }

    /// Reports the video's progress from the writer's queue, only when it moved by half a percent.
    private final class Progress: @unchecked Sendable {
        private let duration: Double
        private let report: @Sendable (Double) -> Void
        private var last = 0.0

        init(duration: Double, report: @escaping @Sendable (Double) -> Void) {
            self.duration = duration
            self.report = report
        }

        func update(to time: CMTime) {
            let fraction = min(max(time.seconds / duration, 0), 1)
            guard fraction - last >= 0.005 else { return }
            last = fraction
            report(fraction)
        }
    }

    /// Feeds each stream's samples from the reader to the writer, each on a queue of its own, as the writer takes
    /// them. One queue for all deadlocked: the reader's `copyNextSampleBuffer` for one stream can wait until another
    /// stream's samples are taken, which can't happen while it blocks their shared queue. Every export on the CI
    /// runner hung that way, while it passed on an M5.
    private final class Pump: @unchecked Sendable {
        private let reader: AVAssetReader
        private let streams: [Stream]
        private let progress: Progress

        init(reader: AVAssetReader, streams: [Stream], progress: Progress) {
            self.reader = reader
            self.streams = streams
            self.progress = progress
        }

        /// Stops the reader, which ends every stream.
        func cancel() {
            reader.cancelReading()
        }

        /// Returns once every stream is finished: out of samples, or the writer or the reader failed.
        func run() async {
            await withCheckedContinuation { continuation in
                let group = DispatchGroup()
                for (index, stream) in streams.enumerated() {
                    group.enter()
                    let queue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier ?? "Reco").export.\(index)")
                    stream.input.requestMediaDataWhenReady(on: queue) { [progress] in
                        while stream.input.isReadyForMoreMediaData {
                            guard let sample = stream.output.copyNextSampleBuffer(), stream.input.append(sample) else {
                                stream.input.markAsFinished()
                                group.leave()
                                return
                            }
                            if stream.isVideo {
                                progress.update(to: sample.presentationTimeStamp)
                            }
                        }
                    }
                }
                group.notify(queue: .global()) { continuation.resume() }
            }
        }
    }

    private static var audioSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
    }

    /// Writes `composition` to `url` and reports progress from 0 to 1. Cancelling the calling task stops the
    /// reader, and the writer after it; the partial file is the caller's to remove.
    @concurrent
    static func write(
        _ composition: EditorComposition, to url: URL, as settings: ExportSettings, progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let videoComposition = composition.videoComposition
        let hdr = videoComposition.colorTransferFunction != nil
        let reader = try AVAssetReader(asset: composition.asset)
        let writer = try AVAssetWriter(outputURL: url, fileType: settings.format == .mp4 ? .mp4 : .mov)

        // The compositor's frames go to the writer in the format it encodes from, so none is converted twice
        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: try await composition.asset.loadTracks(withMediaType: .video),
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: pixelFormat(for: settings, hdr: hdr)]
        )
        videoOutput.videoComposition = videoComposition
        videoOutput.alwaysCopiesSampleData = false
        let videoInput = AVAssetWriterInput(
            mediaType: .video, outputSettings: videoSettings(for: settings, composition: videoComposition, hdr: hdr)
        )
        var streams = [Stream(output: videoOutput, input: videoInput, isVideo: true)]

        let audioTracks = try await composition.asset.loadTracks(withMediaType: .audio)
        if !audioTracks.isEmpty {
            let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: audioSettings)
            audioOutput.audioMix = composition.audioMix
            audioOutput.alwaysCopiesSampleData = false
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings(for: settings))
            streams.append(Stream(output: audioOutput, input: audioInput, isVideo: false))
        }
        for stream in streams {
            reader.add(stream.output)
            writer.add(stream.input)
        }
        guard reader.startReading() else { throw reader.error ?? AVError(.unknown) }
        guard writer.startWriting() else { throw writer.error ?? AVError(.unknown) }
        writer.startSession(atSourceTime: .zero)

        let pump = Pump(reader: reader, streams: streams, progress: Progress(duration: composition.asset.duration.seconds, report: progress))
        // Cancelling stops the reader, which ends every stream, so the writer is finished or cancelled below
        await withTaskCancellationHandler {
            await pump.run()
        } onCancel: {
            pump.cancel()
        }

        if Task.isCancelled || writer.status == .failed || reader.status == .failed {
            let error = Task.isCancelled ? CancellationError() : writer.error ?? reader.error ?? AVError(.unknown)
            reader.cancelReading()
            writer.cancelWriting()
            throw error
        }
        // Not `await writer.finishWriting()`: see `finishWritingWithoutAsyncImport`
        await writer.finishWritingWithoutAsyncImport()
        guard writer.status == .completed else { throw writer.error ?? AVError(.unknown) }
    }

    /// 32-bit BGRA for SDR, which also carries ProRes 4444's alpha. For HDR, the 10-bit formats the encoders
    /// take, and half floats for ProRes 4444.
    private static func pixelFormat(for settings: ExportSettings, hdr: Bool) -> OSType {
        guard hdr else { return kCVPixelFormatType_32BGRA }
        switch settings.format {
        case .mp4, .gif: return kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        case .proRes: return settings.transparentCanvas ? kCVPixelFormatType_64RGBAHalf : kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange
        }
    }

    private static func videoSettings(for settings: ExportSettings, composition: AVVideoComposition, hdr: Bool) -> [String: Any] {
        var videoSettings: [String: Any] = [
            AVVideoWidthKey: Int(composition.renderSize.width),
            AVVideoHeightKey: Int(composition.renderSize.height)
        ]
        // As the recorder tags its files; HDR ProRes is tagged by the frames' own attachments, since the writer
        // refuses color properties for its high-bit-depth formats
        let colorProperties: [String: Any] = hdr ? [
            AVVideoColorPrimariesKey: composition.colorPrimaries ?? AVVideoColorPrimaries_ITU_R_2020,
            AVVideoTransferFunctionKey: composition.colorTransferFunction ?? AVVideoTransferFunction_SMPTE_ST_2084_PQ,
            AVVideoYCbCrMatrixKey: composition.colorYCbCrMatrix ?? AVVideoYCbCrMatrix_ITU_R_2020
        ] : [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
        ]

        switch settings.format {
        case .mp4, .gif:
            let frameRate = 1 / composition.frameDuration.seconds
            var compression: [String: Any] = [
                AVVideoAverageBitRateKey: Int(settings.videoBitRate(size: composition.renderSize, frameRate: frameRate) ?? 0),
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoAllowFrameReorderingKey: true
            ]
            if hdr {
                compression[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main10_AutoLevel as String
            }
            videoSettings[AVVideoCodecKey] = AVVideoCodecType.hevc
            videoSettings[AVVideoCompressionPropertiesKey] = compression
            videoSettings[AVVideoColorPropertiesKey] = colorProperties
        case .proRes:
            videoSettings[AVVideoCodecKey] = settings.proResCodec
            if !hdr {
                videoSettings[AVVideoColorPropertiesKey] = colorProperties
            }
        }
        return videoSettings
    }

    /// AAC at 128 kbit/s in an MP4, uncompressed in a ProRes movie.
    private static func audioOutputSettings(for settings: ExportSettings) -> [String: Any] {
        guard settings.format == .mp4 else { return audioSettings }
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: Int(ExportSettings.aacBitRate)
        ]
    }
}
