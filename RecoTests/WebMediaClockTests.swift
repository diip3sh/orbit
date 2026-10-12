//
//  WebMediaClockTests.swift
//  RecoTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
@testable import Reco

/// A page's videos in a take play on the take's clock (spec 0010, step 1), however long a frame
/// takes to render.
@MainActor
struct WebMediaClockTests {

    /// 60 frames at 30 fps, 64 × 64, each showing its index in binary: six bands, top to bottom
    /// from the lowest bit, white for a one.
    private static func countingMovie() async throws -> Data {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_000_000]
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for index in 0..<60 {
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &buffer)
            let pixels = try #require(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            let bytes = try #require(CVPixelBufferGetBaseAddress(pixels)?.assumingMemoryBound(to: UInt8.self))
            let rowBytes = CVPixelBufferGetBytesPerRow(pixels)
            for row in 0..<64 {
                let value: UInt8 = row < 60 && index & (1 << (row / 10)) != 0 ? 255 : 0
                for column in 0..<64 {
                    let offset = row * rowBytes + column * 4
                    (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3]) = (value, value, value, 255)
                }
            }
            CVPixelBufferUnlockBaseAddress(pixels, [])
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWritingWithoutAsyncImport()
        return try Data(contentsOf: url)
    }

    /// A page playing `movie` from a blob, looping, at 320 × 320 in the top-left corner.
    private static func page(playing movie: Data, attributes: String) -> String {
        """
        <!doctype html><html><body style="margin: 0; background: #000">
        <video id="clip" muted playsinline loop \(attributes) style="width: 320px; height: 320px; display: block"></video>
        <script>
        const bytes = Uint8Array.from(atob('\(movie.base64EncodedString())'), character => character.charCodeAt(0));
        clip.src = URL.createObjectURL(new Blob([bytes], { type: 'video/mp4' }));
        </script></body></html>
        """
    }

    private func take(of page: String) async throws -> AVURLAsset {
        var script = WebScript()
        script.url = URL(string: "data:text/html;charset=utf-8," + (page.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""))
        script.viewport = CGSize(width: 640, height: 400)
        script.scale = 1
        script.duration = 1
        let movie = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
        _ = try await WebPageRenderer(script: script).render(to: movie, bitsPerPixel: 0.4) { _ in }
        return AVURLAsset(url: movie)
    }

    /// The video's frame index in each of the take's frames.
    @concurrent nonisolated private func indices(in take: AVURLAsset) async throws -> [Int] {
        let generator = AVAssetImageGenerator(asset: take)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        var indices: [Int] = []
        for frame in 0..<60 {
            let image = CIImage(cgImage: try await generator.image(at: CMTime(value: CMTimeValue(frame), timescale: 60)).image)
            // Each band is 50 px tall at 320 px
            indices.append((0..<6).reduce(0) { index, bit in
                image.pixel(at: CGPoint(x: 160, y: image.extent.height - 1 - Double(bit * 50 + 25)))[1] > 128 ? index | 1 << bit : index
            })
        }
        return indices
    }

    @Test(arguments: ["autoplay", "autoplay preload=\"none\""])
    func aVideoAdvancesOneTakeFrameAtATime(attributes: String) async throws {
        let take = try await take(of: Self.page(playing: try await Self.countingMovie(), attributes: attributes))
        defer { try? FileManager.default.removeItem(at: take.url) }

        let indices = try await indices(in: take)

        // Half a 30 fps frame per 60 fps frame, looping at 60: one second moves it 30 frames on
        let steps = zip(indices, indices.dropFirst()).map { ($1 - $0 + 60) % 60 }
        #expect(steps.allSatisfy { $0 <= 1 }, "\(indices)")
        #expect(abs(steps.reduce(0, +) - 29) <= 1, "\(indices)")
    }
}
