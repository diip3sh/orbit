//
//  HDREditorCompositor.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import AVFoundation

/// Draws HDR recordings in HDR, which AVFoundation would otherwise convert to SDR first: 10-bit
/// frames in (HEVC Main 10 and ProRes 422 decode to them, ProRes 4444 to half floats), half-float
/// frames out, with room for 10-bit HDR and alpha.
nonisolated final class HDREditorCompositor: EditorCompositor, @unchecked Sendable {

    @objc var supportsHDRSourceFrames: Bool {
        true
    }

    override var sourcePixelBufferAttributes: [String: any Sendable]? {
        [kCVPixelBufferPixelFormatTypeKey as String: [
            kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr10BiPlanarFullRange,
            kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange, kCVPixelFormatType_64RGBAHalf
        ]]
    }

    override var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_64RGBAHalf]
    }
}
