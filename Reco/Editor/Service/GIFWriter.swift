//
//  GIFWriter.swift
//  Reco
//
//  Created by Diip3sh on 02.10.26.
//

import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import VideoToolbox

/// Writes an edited video as a looping GIF: frames drawn by the same video composition as every
/// export, each encoded by ImageIO and joined by ``GIFFrame``, so memory stays at one frame.
///
/// Each frame has its own 256 colors and no dithering, so gradients band.
nonisolated enum GIFWriter {

    /// Writes to `url`, replacing any file there, and reports progress from 0 to 1. Cancelling the
    /// calling task stops it. The caller removes a partial file.
    /// - Parameter videoComposition: Its frame duration should be 0.02 or 0.04 s: GIF stores
    ///   delays in hundredths of a second.
    @concurrent
    static func write(
        _ asset: AVAsset, videoComposition: AVVideoComposition, to url: URL, progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let duration = try await asset.load(.duration).seconds
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderVideoCompositionOutput(
            videoTracks: try await asset.loadTracks(withMediaType: .video),
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        output.videoComposition = videoComposition
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? CocoaError(.fileReadUnknown)
        }
        defer { reader.cancelReading() }

        guard FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let file = try FileHandle(forWritingTo: url)
        defer { try? file.close() }

        let delay = max(Int((videoComposition.frameDuration.seconds * 100).rounded()), 2)
        // Written once the next frame differs: a frame that repeats only shows longer
        var pending: (frame: GIFFrame, delay: Int)?
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let buffer = sample.imageBuffer else { continue }
            let frame = try frame(from: buffer)
            if let last = pending, last.frame == frame, last.delay + delay <= GIFFrame.maximumDelay {
                pending?.delay += delay
            } else {
                if let pending {
                    try file.write(contentsOf: pending.frame.block(delay: pending.delay))
                } else {
                    try file.write(contentsOf: GIFFrame.header(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer)))
                }
                pending = (frame, delay)
            }
            progress(min(sample.presentationTimeStamp.seconds / duration, 1))
        }
        if reader.status == .failed {
            throw reader.error ?? CocoaError(.fileReadUnknown)
        }
        guard let pending else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try file.write(contentsOf: pending.frame.block(delay: pending.delay))
        try file.write(contentsOf: GIFFrame.trailer)
    }

    /// The frame as ImageIO encodes it on its own.
    private static func frame(from buffer: CVPixelBuffer) throws -> GIFFrame {
        var image: CGImage?
        VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &image)
        let data = NSMutableData()
        guard let image, let destination = CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination), let frame = GIFFrame(file: data as Data) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return frame
    }
}
