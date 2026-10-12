//
//  MotionCompositor.swift
//  Reco
//

import AVFoundation
import CoreImage
import OSLog

/// Draws a motion video's frames with ``MotionFrameRenderer``, for the preview and the export alike.
///
/// Stateless: each request carries its plan in its ``MotionInstruction``, so frames are drawn in any
/// order and in parallel. AVFoundation creates the instances.
nonisolated final class MotionCompositor: NSObject, AVVideoCompositing, Sendable {

    /// Shared: a context is thread-safe and costly to create. Without color management, as the
    /// editor's: colors are drawn as written, in sRGB, and the output is tagged BT.709.
    private static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])

    private static let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "MotionCompositor")

    var sourcePixelBufferAttributes: [String: any Sendable]? {
        [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_32BGRA]]
    }

    // swiftlint:disable:next identifier_name - named by AVVideoCompositing
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        let signpost = Self.signposter.beginInterval("Render frame")
        defer { Self.signposter.endInterval("Render frame", signpost) }

        guard let instruction = request.videoCompositionInstruction as? MotionInstruction,
              let output = request.renderContext.newPixelBuffer() else {
            request.finish(with: AVError(.unknown))
            return
        }
        // Each live layer's take, at the time its track plays
        var frames: [MotionPlan.LayerKey: CIImage] = [:]
        for (key, track) in instruction.liveTracks {
            if let buffer = request.sourceFrame(byTrackID: track) {
                frames[key] = CIImage(cvPixelBuffer: buffer)
            }
        }
        do {
            try MotionFrameRenderer.draw(at: request.compositionTime.seconds, plan: instruction.plan, frames: frames, into: output, context: Self.context)
            request.finish(withComposedVideoFrame: output)
        } catch {
            request.finish(with: error)
        }
    }
}
