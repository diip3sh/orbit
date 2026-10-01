//
//  RenderTarget.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics

/// What a plan is drawn for: the preview, or an export at another size or in SDR.
nonisolated struct RenderTarget: Equatable, Sendable {

    /// The output's shorter side in pixels, or `nil` for the canvas's own: the video's.
    var shorterSide: CGFloat?

    /// Whether an HDR recording is drawn in HDR; otherwise AVFoundation converts its frames to SDR.
    var keepsHDR = true

    static let preview = RenderTarget()
}
