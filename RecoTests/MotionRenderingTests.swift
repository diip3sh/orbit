//
//  MotionRenderingTests.swift
//  RecoTests
//

import AVFoundation
import CoreImage
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Reco

/// The demo document drawn by the renderer, the preview's composition and an export: golden frames
/// at 480 px, and the same pixels on every path.
@MainActor
struct MotionRenderingTests {

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// A title fading up, the plane at rest, mid-push and at the push's end.
    private static let goldenTimes = [0.5, 1.5, 2.5, 4.9]

    @Test func goldenFrames() async throws {
        let (url, document) = try MotionTestBundle.make()
        defer { try? FileManager.default.removeItem(at: url) }
        let plan = await MotionPlan.build(document, bundle: url, shorterSide: 270)

        for time in Self.goldenTimes {
            try Self.expectGolden("motion-demo-\(Int(time * 1000))", MotionFrameRenderer.image(at: time, plan: plan))
        }
    }

    /// Each shot of the grammar, its reveals and its seams, drawn from `motion-grammar.json`: the title
    /// wiping in and settled, the hook blurring in, the hero's band of focus, the focus dimmed, a push
    /// half way, the cascade, both features, the roll wiping in and rolled, the end card faded in.
    @Test func grammarGoldenFrames() async throws {
        let (url, document) = try MotionTestBundle.makeGrammar()
        defer { try? FileManager.default.removeItem(at: url) }
        let plan = await MotionPlan.build(document, bundle: url, shorterSide: 270)

        #expect(plan.liftsNeeded.isEmpty)
        for time in [0.5, 2.0, 3.1, 7.0, 10.5, 12.1, 13.0, 15.0, 18.0, 19.9, 21.0, 22.6, 25.5] {
            try Self.expectGolden("motion-grammar-\(Int(time * 1000))", MotionFrameRenderer.image(at: time, plan: plan))
        }
    }

    /// Compares `image` with the golden frame `name`; a missing one is written to the temporary folder.
    private static func expectGolden(_ name: String, _ image: CIImage) throws {
        let frame = try pixels(of: image)
        guard let golden = Fixture.url(name, withExtension: "png") else {
            let written = URL.temporaryDirectory.appending(path: "\(name).png")
            try writePNG(frame, to: written)
            Issue.record("No golden frame \(name).png; this frame was written to \(written.path())")
            return
        }
        let goldenImage = try #require(CIImage(contentsOf: golden))
        let difference = try difference(frame, pixels(of: goldenImage))
        #expect(difference.mean < 0.5, "\(name): mean difference \(difference.mean)")
        #expect(difference.most <= 32, "\(name): largest difference \(difference.most)")
    }

    @Test func thePreviewDrawsWhatTheRendererDraws() async throws {
        let (url, document) = try MotionTestBundle.make()
        defer { try? FileManager.default.removeItem(at: url) }
        let plan = await MotionPlan.build(document, bundle: url, shorterSide: 270)
        let composition = try await MotionCompositionBuilder.composition(for: plan)

        #expect(try await composition.asset.load(.duration) == CMTime(value: 300, timescale: 60))
        for time in [0.5, 3.25] {
            let previewed = try await ExportService.frame(of: composition, at: CMTime(seconds: time, preferredTimescale: 60))
            let difference = try Self.difference(Self.pixels(of: CIImage(cgImage: previewed)), Self.pixels(of: MotionFrameRenderer.image(at: time, plan: plan)))
            #expect(difference.mean < 0.5)
        }
    }

    @Test func exportsTheVideoAndAGIF() async throws {
        let (url, document) = try MotionTestBundle.make()
        defer { try? FileManager.default.removeItem(at: url) }

        let movie = try await MotionExporter.export(document, bundle: url, settings: ExportSettings(format: .hevc, resolution: 720)) { _ in }
        defer { try? FileManager.default.removeItem(at: movie) }
        let asset = AVURLAsset(url: movie)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(movie.lastPathComponent == url.deletingPathExtension().lastPathComponent + "-edited.mp4")
        #expect(try await track.load(.naturalSize) == CGSize(width: 1280, height: 720))
        #expect(abs(try await track.load(.timeRange).duration.seconds - 5) < 1.0 / 60)

        // The exported frame is the renderer's, through the codec
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let exported: CGImage = try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: CMTime(value: 195, timescale: 60)) { image, _, error in
                continuation.resume(with: Result { try image ?? { throw error ?? CocoaError(.fileReadUnknown) }() })
            }
        }
        let plan = await MotionPlan.build(document, bundle: url, shorterSide: 720)
        let difference = try Self.difference(Self.pixels(of: CIImage(cgImage: exported)), Self.pixels(of: MotionFrameRenderer.image(at: 3.25, plan: plan)))
        #expect(difference.mean < 3)

        let gif = try await MotionExporter.export(document, bundle: url, settings: ExportSettings(format: .gif)) { _ in }
        defer { try? FileManager.default.removeItem(at: gif) }
        let source = try #require(CGImageSourceCreateWithURL(gif as CFURL, nil))
        #expect(CGImageSourceGetCount(source) > 1)
        let first = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(first.height == 540)
    }

    // MARK: - Pixels

    private struct Pixels {
        let width: Int
        let height: Int
        let bytes: [UInt8]
    }

    /// The image's 8-bit values as stored, without color management.
    private static func pixels(of image: CIImage) throws -> Pixels {
        let extent = image.extent.integral
        var bytes = [UInt8](repeating: 0, count: Int(extent.width * extent.height) * 4)
        context.render(image, toBitmap: &bytes, rowBytes: Int(extent.width) * 4, bounds: extent, format: .RGBA8, colorSpace: nil)
        return Pixels(width: Int(extent.width), height: Int(extent.height), bytes: bytes)
    }

    private static func difference(
        _ first: Pixels, _ second: Pixels
    ) throws -> (mean: Double, most: Int) {
        try #require(first.width == second.width && first.height == second.height)
        var total = 0
        var most = 0
        for (one, other) in zip(first.bytes, second.bytes) {
            let difference = abs(Int(one) - Int(other))
            total += difference
            most = max(most, difference)
        }
        return (Double(total) / Double(first.bytes.count), most)
    }

    private static func writePNG(_ pixels: Pixels, to url: URL) throws {
        var bytes = pixels.bytes
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: &bytes, width: pixels.width, height: pixels.height, bitsPerComponent: 8, bytesPerRow: pixels.width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}
