//
//  VideoCrop.swift
//  Reco
//

import CoreGraphics

/// The part of the recording the editor keeps (spec 0004, N11), as fractions of the video from its top-left corner.
/// Everything after it treats the crop as the video: the canvas, zooms (their focus is in fractions of the crop),
/// the cursor and clicks, through ``InputTelemetry/cropped(to:)``.
nonisolated enum VideoCrop {

    static let full = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// The smallest share of the video's width and height a crop keeps
    static let minimumSize = 0.1

    /// `crop` at least ``minimumSize`` on each side and inside the video
    static func clamped(_ crop: CGRect) -> CGRect {
        RegionDrag.clamped(crop, minimumSize: minimumSize)
    }

    /// `crop` in the video's pixels, top-left origin, on whole pixels with even sides (4:2:0 video needs them); the
    /// whole video, whatever its size, when nothing is cropped.
    static func pixels(of crop: CGRect, in videoSize: CGSize) -> CGRect {
        let crop = clamped(crop)
        guard crop != full else { return CGRect(origin: .zero, size: videoSize) }
        let left = (crop.minX * videoSize.width).rounded()
        let top = (crop.minY * videoSize.height).rounded()
        let width = (min(crop.width * videoSize.width, videoSize.width - left) / 2).rounded(.down) * 2
        let height = (min(crop.height * videoSize.height, videoSize.height - top) / 2).rounded(.down) * 2
        return CGRect(x: left, y: top, width: width, height: height)
    }

    /// `pixels` (top-left origin) in Core Image's space, bottom-left origin, for a video `videoHeight` pixels high
    static func coreImageRect(_ pixels: CGRect, videoHeight: CGFloat) -> CGRect {
        CGRect(x: pixels.minX, y: videoHeight - pixels.maxY, width: pixels.width, height: pixels.height)
    }
}

extension InputTelemetry {

    /// The telemetry of the video cut to `pixels` (top-left origin): every position lands where it is in the crop,
    /// in pixels and in fractions, and outside it when it was outside. Only the geometry changes, which holds an
    /// entry per change of capture, so this is cheap.
    nonisolated func cropped(to pixels: CGRect) -> InputTelemetry {
        guard pixels.origin != .zero || pixels.size != capture.videoSize else { return self }
        var telemetry = self
        telemetry.capture.videoSize = pixels.size
        telemetry.geometry = geometry.map { geometry in
            var geometry = geometry
            // `videoPixel` is (contentRect.origin + …) × scaleFactor, so this moves every pixel by the crop's origin
            geometry.contentRect.origin.x -= pixels.minX / geometry.scaleFactor
            geometry.contentRect.origin.y -= pixels.minY / geometry.scaleFactor
            return geometry
        }
        return telemetry
    }
}
