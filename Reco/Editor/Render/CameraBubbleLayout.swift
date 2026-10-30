//
//  CameraBubbleLayout.swift
//  Reco
//

import CoreGraphics

/// Where the camera bubble sits. Frames here are the video's place on the canvas, in Core Image pixels.
nonisolated enum CameraBubbleLayout {

    /// How far a corner preset sits from the video's edges, as a share of its shorter side.
    static let margin = 0.03

    /// The smallest a zoom shrinks the bubble, reached at 2× and past it.
    static let smallestShrink = 0.6

    /// `style`'s bubble in `videoFrame`, whole inside it and on whole pixels, in Core Image pixels.
    static func rect(of style: CameraOverlayStyle, in videoFrame: CGRect) -> CGRect {
        let side = (style.size * min(videoFrame.width, videoFrame.height)).rounded()
        let center = clamped(style.center, size: style.size, in: videoFrame.size)
        return CGRect(
            x: (videoFrame.minX + center.x * videoFrame.width - side / 2).rounded(),
            y: (videoFrame.maxY - center.y * videoFrame.height - side / 2).rounded(),
            width: side, height: side
        )
    }

    /// `center` moved so a bubble of `size` stays whole inside the video.
    static func clamped(_ center: CGPoint, size: Double, in videoSize: CGSize) -> CGPoint {
        let half = size * min(videoSize.width, videoSize.height) / 2
        let (halfX, halfY) = (min(half / videoSize.width, 0.5), min(half / videoSize.height, 0.5))
        return CGPoint(x: min(max(center.x, halfX), 1 - halfX), y: min(max(center.y, halfY), 1 - halfY))
    }

    /// The centre that puts a bubble of `size` in `corner` of a `videoSize` video.
    static func center(of corner: CameraOverlayStyle.Corner, size: Double, in videoSize: CGSize) -> CGPoint {
        let reach = (size / 2 + margin) * min(videoSize.width, videoSize.height)
        let (left, top) = (reach / videoSize.width, reach / videoSize.height)
        return switch corner {
        case .topLeft: CGPoint(x: left, y: top)
        case .topRight: CGPoint(x: 1 - left, y: top)
        case .bottomLeft: CGPoint(x: left, y: 1 - top)
        case .bottomRight: CGPoint(x: 1 - left, y: 1 - top)
        }
    }

    /// How much of its size the bubble keeps at camera zoom `zoom`: all at 1×, falling with the zoom, which eases, so it
    /// eases too.
    static func shrink(atZoom zoom: Double) -> Double {
        max(smallestShrink, 1 - (1 - smallestShrink) * (zoom - 1))
    }

    /// Maps a bubble drawn with its corner at the origin onto `rect` shrunk by `scale` toward `videoFrame`'s nearest
    /// corner, so it keeps to its corner and doesn't drift off the edge's margin.
    static func placement(of rect: CGRect, scale: Double, in videoFrame: CGRect) -> CGAffineTransform {
        let anchor = CGPoint(
            x: rect.midX < videoFrame.midX ? videoFrame.minX : videoFrame.maxX,
            y: rect.midY < videoFrame.midY ? videoFrame.minY : videoFrame.maxY
        )
        return CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(
            translationX: anchor.x + (rect.minX - anchor.x) * scale, y: anchor.y + (rect.minY - anchor.y) * scale
        ))
    }

    /// A bubble at `rect` on a `canvas` in the coordinates of a view of `viewSize` that shows it, top-left origin.
    static func viewRect(of rect: CGRect, canvas: CGSize, viewSize: CGSize) -> CGRect {
        let (scaleX, scaleY) = (viewSize.width / canvas.width, viewSize.height / canvas.height)
        return CGRect(x: rect.minX * scaleX, y: (canvas.height - rect.maxY) * scaleY, width: rect.width * scaleX, height: rect.height * scaleY)
    }

    /// A drag of `translation` points in a view of `viewSize` showing `canvas`, as fractions of a `videoSize` video on it.
    static func videoShare(of translation: CGSize, viewSize: CGSize, canvas: CGSize, videoSize: CGSize) -> CGSize {
        CGSize(
            width: translation.width * canvas.width / viewSize.width / videoSize.width,
            height: translation.height * canvas.height / viewSize.height / videoSize.height
        )
    }
}
