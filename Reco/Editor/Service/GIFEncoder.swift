//
//  GIFEncoder.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Writes a composition as an animated GIF: the reader draws each frame, ImageIO encodes it, ``GIFMuxer`` joins them.
nonisolated enum GIFEncoder {

    /// The delay after frame `index` in centiseconds, the GIF's only unit. Cumulative, so rounding never drifts:
    /// 30 fps gives 3, 4, 3, 3, 4, 3… instead of 3 every time, which would play 10% fast.
    static func delay(ofFrame index: Int, frameRate: Double) -> Int {
        Int((100 * Double(index + 1) / frameRate).rounded()) - Int((100 * Double(index) / frameRate).rounded())
    }

    /// Writes `composition` to `url` at the composition's frame rate and size, looping forever. Cancelling the
    /// calling task stops it; the partial file is the caller's to remove.
    ///
    /// Each frame is encoded and written as it arrives (see ``GIFMuxer``), so memory doesn't grow with the length.
    @concurrent
    static func write(_ composition: EditorComposition, to url: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        let videoComposition = composition.videoComposition
        let frameRate = 1 / videoComposition.frameDuration.seconds
        let duration = composition.asset.duration.seconds
        let expectedFrames = max(1, duration * frameRate)

        let reader = try AVAssetReader(asset: composition.asset)
        let output = AVAssetReaderVideoCompositionOutput(
            videoTracks: try await composition.asset.loadTracks(withMediaType: .video),
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        output.videoComposition = videoComposition
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? AVError(.unknown) }
        defer { reader.cancelReading() }

        guard FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let file = try FileHandle(forWritingTo: url)
        defer { try? file.close() }
        try file.write(contentsOf: GIFMuxer.header(width: Int(videoComposition.renderSize.width), height: Int(videoComposition.renderSize.height)))

        let frames = Frames(reader: reader, output: output, file: file, frameRate: frameRate, expectedFrames: expectedFrames, progress: progress)
        // `copyNextSampleBuffer` blocks until the compositor has drawn the frame: on a queue of its own, so it never
        // holds one of the few cooperative threads (3 on the CI runner) the rest of the app's tasks need
        let count = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue(label: "\(Bundle.main.bundleIdentifier ?? "Reco").gif").async {
                    continuation.resume(with: Result { try frames.writeAll() })
                }
            }
        } onCancel: {
            frames.cancel()
        }
        try Task.checkCancellation()
        if reader.status == .failed {
            throw reader.error ?? AVError(.unknown)
        }
        guard count > 0 else { throw AVError(.noDataCaptured) }
        try file.write(contentsOf: GIFMuxer.trailer)
    }

    /// Reads every frame and appends it to the file. `writeAll()` runs on one queue only.
    private final class Frames: @unchecked Sendable {
        private let reader: AVAssetReader
        private let output: AVAssetReaderOutput
        private let file: FileHandle
        private let frameRate: Double
        private let expectedFrames: Double
        private let progress: @Sendable (Double) -> Void

        init(reader: AVAssetReader, output: AVAssetReaderOutput, file: FileHandle, frameRate: Double, expectedFrames: Double, progress: @escaping @Sendable (Double) -> Void) {
            self.reader = reader
            self.output = output
            self.file = file
            self.frameRate = frameRate
            self.expectedFrames = expectedFrames
            self.progress = progress
        }

        /// Ends `writeAll()` at the next frame. `cancelReading` may be called from any thread.
        func cancel() {
            reader.cancelReading()
        }

        /// Returns how many frames were written; stops early, without an error, when the reader is cancelled.
        func writeAll() throws -> Int {
            var count = 0
            while let sample = output.copyNextSampleBuffer() {
                guard let buffer = sample.imageBuffer, let image = GIFEncoder.image(of: buffer) else { throw AVError(.unknown) }
                try file.write(contentsOf: try GIFEncoder.frame(of: image, delay: GIFEncoder.delay(ofFrame: count, frameRate: frameRate)))
                count += 1
                progress(min(Double(count) / expectedFrames, 1))
            }
            return count
        }
    }

    /// One frame's blocks for the file, from a one-frame GIF of `image`.
    private static func frame(of image: CGImage, delay: Int) throws -> Data {
        let single = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(single, UTType.gif.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination), let frame = GIFMuxer.frame(from: single as Data, delay: delay) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return frame
    }

    /// The frame as an image of its own: the buffer goes back to the reader's pool for the next frame. The
    /// alpha is skipped, so a transparent background is the black it exports as everywhere but ProRes 4444.
    private static func image(of buffer: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        return CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )?.makeImage()
    }
}
