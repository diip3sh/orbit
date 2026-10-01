//
//  WebMovieWriter.swift
//  Reco
//

import AVFoundation
import CoreGraphics
import CoreVideo

/// Writes a take's snapshots, one per frame, to an HEVC movie tagged SDR BT.709.
///
/// Snapshots come slower than real time, so the input doesn't expect real-time data and each
/// append waits until the encoder is ready.
actor WebMovieWriter {

    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let size: CGSize
    private let frameRate: Int32

    /// - Parameter bitsPerPixel: The average bitrate per pixel and frame.
    init(url: URL, size: CGSize, frameRate: Int, bitsPerPixel: Double) throws {
        // The output folder may not exist yet, e.g. before the first recording; AVAssetWriter won't make it
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(size.width * size.height * bitsPerPixel * Double(frameRate)),
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoMaxKeyFrameIntervalKey: frameRate * 2
            ],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        ])
        input.expectsMediaDataInRealTime = false
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ])
        writer.add(input)
        self.size = size
        self.frameRate = Int32(frameRate)
        guard writer.startWriting() else {
            throw writer.error ?? WebRenderError.writerFailed
        }
        writer.startSession(atSourceTime: .zero)
    }

    /// Appends `image`, drawn to fill the movie's size, as frame number `frame`.
    func append(_ image: CGImage, frame: Int) async throws {
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw writer.error ?? WebRenderError.writerFailed }
            try await Task.sleep(for: .milliseconds(2))
        }
        guard let pool = adaptor.pixelBufferPool else { throw writer.error ?? WebRenderError.writerFailed }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { throw WebRenderError.writerFailed }

        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard context != nil else { throw WebRenderError.writerFailed }

        guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: frameRate)) else {
            throw writer.error ?? WebRenderError.writerFailed
        }
    }

    /// Finishes the movie after the last frame, which lasts one frame.
    func finish(frameCount: Int) async throws {
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frameCount), timescale: frameRate))
        await writer.finishWritingWithoutAsyncImport()
        guard writer.status == .completed else { throw writer.error ?? WebRenderError.writerFailed }
    }

    /// Stops writing, e.g. when the take is cancelled. The caller removes the file.
    func cancel() {
        writer.cancelWriting()
    }
}
