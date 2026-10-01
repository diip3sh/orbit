//
//  EditorCompositor.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation
import CoreImage
import OSLog

/// Draws the editor's frames with ``FrameRenderer``, for the preview and the export alike.
///
/// Stateless: each request carries its plan in its ``EditorInstruction``, so AVFoundation can ask
/// for frames in any order and in parallel. AVFoundation creates the instances. HDR recordings are
/// drawn by ``HDREditorCompositor``.
///
/// `@unchecked` only because it isn't final, for that subclass; neither has stored state.
nonisolated class EditorCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {

    /// Shared by every compositor: a context is thread-safe and costly to create. Intermediates
    /// aren't cached, as recommended for video, where every frame differs.
    ///
    /// Color management is off, so frames are composited in the source's own encoding, HDR too:
    /// its pixels pass through untouched, and a 4K frame with a ring and a chip renders in about
    /// 5 ms p50, 8 ms p95 on an M1 instead of 10 and 13 ms converting every pixel to linear and back.
    private static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])

    private static let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "EditorCompositor")

    /// The decoder's own formats for H.264 and HEVC, so frames arrive without a conversion.
    var sourcePixelBufferAttributes: [String: any Sendable]? {
        [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]]
    }

    // swiftlint:disable:next identifier_name - named by AVVideoCompositing
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        let signpost = Self.signposter.beginInterval("Render frame")
        defer { Self.signposter.endInterval("Render frame", signpost) }

        guard let instruction = request.videoCompositionInstruction as? EditorInstruction,
              let output = request.renderContext.newPixelBuffer() else {
            request.finish(with: AVError(.unknown))
            return
        }
        let plan = instruction.plan

        // Black where the video track has no frame, e.g. audio running past its end
        let source = request.sourceFrame(byTrackID: instruction.sourceTrackID)
        let frame = source.map { CIImage(cvPixelBuffer: $0) } ?? CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: plan.videoSize))
        if let source {
            // The output keeps the source's encoding, so it carries its color tags
            CVBufferPropagateAttachments(source, output)
        }

        let time = plan.timeMap.sourceTime(atOutput: request.compositionTime.seconds)
        do {
            try FrameRenderer.draw(frame, at: time, plan: plan, into: output, context: Self.context)
            request.finish(withComposedVideoFrame: output)
        } catch {
            request.finish(with: error)
        }
    }
}
