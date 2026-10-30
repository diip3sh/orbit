//
//  CameraOverlayStyle.swift
//  Reco
//

import CoreGraphics

/// How the camera bubble looks and lines up. A bubble is always square; shares are of the video on the canvas, so it's
/// the same at every export size.
nonisolated struct CameraOverlayStyle: Codable, Equatable, Sendable {

    /// A corner of the video to snap the bubble to.
    nonisolated enum Corner: CaseIterable, Sendable {
        case topLeft, topRight, bottomLeft, bottomRight

        var title: String {
            switch self {
            case .topLeft: "Top Left"
            case .topRight: "Top Right"
            case .bottomLeft: "Bottom Left"
            case .bottomRight: "Bottom Right"
            }
        }

        var symbol: String {
            switch self {
            case .topLeft: "arrow.up.left"
            case .topRight: "arrow.up.right"
            case .bottomLeft: "arrow.down.left"
            case .bottomRight: "arrow.down.right"
            }
        }
    }

    /// `false` hides the footage, which stays on disk.
    var isEnabled = true

    /// The bubble's centre, as fractions of the video from its top-left corner. Bottom right on a 16:9 video.
    var center = CGPoint(x: 0.9, y: 0.82)

    /// The side, as a share of the shorter side of the video on the canvas.
    var size = 0.25

    /// How round the corners are, from 0 (a square) to 1 (a circle).
    var roundness = 1.0

    /// Flipped sideways, as people see themselves in a mirror and in most video calls.
    var isMirrored = true

    /// How dark the shadow is, from 0 (none) to 1.
    var shadow = 0.5

    /// The part of the camera's frame shown, as fractions of it from its top-left corner. The bubble is filled from
    /// its middle.
    var crop = VideoCrop.full

    /// Seconds added to the footage's own offset, to line it up by hand. Later when positive.
    var timeOffset = 0.0

    /// Whether the bubble gets smaller while a zoom is in, leaving the zoomed content more room.
    var shrinksDuringZooms = true

    /// The range the inspector offers for ``size``.
    static let sizes = 0.1...0.6

    /// The range the inspector offers for ``timeOffset``.
    static let timeOffsets = -5.0...5.0
}
