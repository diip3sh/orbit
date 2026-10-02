//
//  RenderPlan.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import CoreGraphics
import CoreImage
import Foundation
import OSLog

/// Everything needed to draw any frame, precomputed when the project changes.
///
/// Immutable and shared by every compositor request, so frames can be rendered in any order and in
/// parallel. Positions are converted to Core Image pixels here, once, never per frame.
nonisolated struct RenderPlan: Sendable {
    let timeMap: TimeMap
    let videoSize: CGSize

    /// Where the camera looks: the zooms, integrated.
    let camera: CameraPath

    /// The cursor the editor draws, or `nil` when the video shows the system's or it's off.
    let cursor: CursorPath?

    /// The drawn cursor's images. Empty without ``cursor``.
    let cursorShapes: CursorShapeTrack

    /// Clicks to highlight, sorted by time. Empty when highlights are off.
    let clicks: [ClickMarker]

    /// How long a click's ring shows, in seconds.
    let clickDuration: Double

    /// The ring at the largest marker's diameter; the others scale it down.
    let clickRing: CIImage

    /// Key presses to show, sorted by time. Empty when the overlay is off.
    let keystrokes: [KeystrokeChip]

    /// One image per distinct label, indexed by ``KeystrokeChip/image``.
    let chipImages: [CIImage]

    /// The output frame, and where the video sits on it.
    let canvas: CanvasLayout

    /// What frames are drawn in: the recording's dynamic range, or SDR for a target that doesn't keep
    /// HDR. The overlays' images are already in its encoding.
    let dynamicRange: DynamicRange

    /// How long the shutter that blurs the camera's moves, and the one that blurs the cursor's, is
    /// open, in seconds. 0 for no blur.
    let cameraShutter: Double
    let cursorShutter: Double

    /// The most samples a blurred frame is averaged from.
    let blurSamples: Int

    /// The shutter at the most motion blur: a frame of film at 24 fps. Half of it is film's usual
    /// 180° shutter.
    static let maximumShutter = 1.0 / 24
}

// MARK: - Building

extension RenderPlan {

    /// A chip's height as a share of the shorter side of the video on the canvas.
    nonisolated private static let chipHeightFraction = 0.06

    nonisolated private static let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "RenderPlan")

    /// Builds the plan off the main actor.
    @concurrent
    static func build(project: EditorProject, source: EditorSource, resources: RenderResources, target: RenderTarget = .preview) async -> RenderPlan {
        let signpost = signposter.beginInterval("Build")
        defer { signposter.endInterval("Build", signpost) }

        let videoSize = source.naturalSize
        let dynamicRange = target.keepsHDR ? source.dynamicRange : .sdr
        // The costliest parts, and independent, so they're built alongside the rest. For 10 minutes
        // with 455 zooms, 3,000 clicks and 12,000 keys (M1, Debug), the camera takes 38 ms and the
        // cursor 35; the plan builds in 42 ms instead of 105
        async let camera = CameraPath(
            zooms: project.zooms, cursor: source.telemetry.map { cursorPoints(for: $0, during: project.zooms) } ?? [], duration: source.duration
        )
        let timeMap = TimeMap(cuts: project.cuts, sourceDuration: source.duration, frameRate: source.frameRate)
        let shown = (timeMap.keptRanges.first?.lowerBound ?? 0)..<(timeMap.keptRanges.last?.upperBound ?? source.duration)
        async let cursor = source.telemetry.flatMap {
            drawnCursor(for: $0, style: project.cursor, duration: source.duration, videoHeight: videoSize.height, arrow: resources.arrow, shown: shown)
        }
        let canvas = CanvasLayout(style: project.canvas, videoSize: videoSize, shorterSide: target.shorterSide, background: resources.background)
            .encoded(in: dynamicRange)

        var clicks: [ClickMarker] = []
        var keystrokes: [KeystrokeChip] = []
        var labels: [String] = []
        if let telemetry = source.telemetry {
            if project.clickHighlights.isEnabled {
                clicks = clickMarkers(for: telemetry, style: project.clickHighlights, videoHeight: videoSize.height)
            }
            if project.keystrokes.isEnabled, let keyLabels = resources.keyLabels {
                (keystrokes, labels) = keystrokeChips(for: telemetry, style: project.keystrokes, keyLabels: keyLabels)
            }
        }

        let ringDiameter = clicks.map(\.diameter).max() ?? 0
        let chipHeight = min(canvas.videoFrame.width, canvas.videoFrame.height) * chipHeightFraction
        return RenderPlan(
            timeMap: timeMap,
            videoSize: videoSize,
            camera: await camera,
            cursor: await cursor?.path,
            cursorShapes: await cursor?.shapes.encoded(in: dynamicRange) ?? .none,
            clicks: clicks,
            clickDuration: project.clickHighlights.duration,
            clickRing: clicks.isEmpty
                ? .empty()
                : OverlayImages.encoded(OverlayImages.ring(diameter: ringDiameter, color: project.clickHighlights.color.cgColor), in: dynamicRange),
            keystrokes: keystrokes,
            chipImages: labels.map { OverlayImages.encoded(OverlayImages.chip(label: $0, height: chipHeight), in: dynamicRange) },
            canvas: canvas,
            dynamicRange: dynamicRange,
            cameraShutter: project.motionBlur * maximumShutter,
            cursorShutter: project.cursor.motionBlur * maximumShutter,
            blurSamples: target.blurSamples
        )
    }

    /// The presses to highlight, each placed with the capture geometry in effect at its time.
    nonisolated static func clickMarkers(for telemetry: InputTelemetry, style: ClickHighlightStyle, videoHeight: CGFloat) -> [ClickMarker] {
        telemetry.clicks.compactMap { click in
            guard click.isDown, style.buttons.includes(click.button), let geometry = telemetry.geometry(at: click.time) else {
                return nil
            }
            let pixel = InputTelemetry.videoPixel(for: click.location, geometry: geometry)
            return ClickMarker(
                time: click.time,
                position: coreImagePoint(pixel, videoHeight: videoHeight),
                diameter: style.size * geometry.contentScale * geometry.scaleFactor
            )
        }
    }

    /// The presses to show and their distinct labels, which ``KeystrokeChip/image`` indexes.
    /// Auto-repeats are left out: a held key shows once.
    nonisolated static func keystrokeChips(
        for telemetry: InputTelemetry, style: KeystrokeOverlayStyle, keyLabels: KeyLabelFormatter
    ) -> (chips: [KeystrokeChip], labels: [String]) {
        var labels: [String] = []
        var images: [String: Int] = [:]
        let chips = telemetry.keys.compactMap { key -> KeystrokeChip? in
            guard !key.isRepeat, let label = keyLabels.label(for: key, showsAllKeys: style.showsAllKeys) else { return nil }
            let image = images[label] ?? labels.count
            if image == labels.count {
                images[label] = image
                labels.append(label)
            }
            return KeystrokeChip(time: key.time, image: image)
        }
        return (chips, labels)
    }

    /// The cursor to draw and its images, or `nil` when the video shows the system's or it's off.
    nonisolated static func drawnCursor(
        for telemetry: InputTelemetry, style: CursorStyle, duration: Double, videoHeight: CGFloat, arrow: InputTelemetry.CursorSprite?,
        shown: Range<Double>? = nil
    ) -> (path: CursorPath, shapes: CursorShapeTrack)? {
        guard !telemetry.capture.cursorInVideo, style.isEnabled,
              let path = CursorPath(telemetry: telemetry, style: style, duration: duration, videoHeight: videoHeight, shown: shown)
        else { return nil }
        return (path, CursorShapeTrack(telemetry: telemetry, duration: duration, arrow: arrow))
    }

    /// The cursor's positions in the video while a zoom follows it, from the one in effect at the
    /// zoom's start, each placed with the capture geometry in effect at its time. The camera needs
    /// no others, and each costs a geometry lookup: 9 ms for half of a 10-minute recording's 60 Hz
    /// samples (M1, Debug).
    nonisolated static func cursorPoints(for telemetry: InputTelemetry, during zooms: [ZoomSegment]) -> [(time: Double, point: CGPoint)] {
        zooms.filter(\.followsCursor).flatMap { zoom in
            let first = max(telemetry.cursor.partitioningIndex { $0.time > zoom.range.lowerBound } - 1, 0)
            let end = min(max(telemetry.cursor.partitioningIndex { $0.time >= zoom.range.upperBound }, first + 1), telemetry.cursor.count)
            return telemetry.cursor[first..<end].compactMap { sample in
                telemetry.normalizedVideoPoint(for: sample.location, at: sample.time).map { (sample.time, $0) }
            }
        }
    }

    /// Flips a video pixel (top-left origin, as telemetry maps it) into Core Image space
    /// (bottom-left origin).
    nonisolated static func coreImagePoint(_ videoPixel: CGPoint, videoHeight: CGFloat) -> CGPoint {
        CGPoint(x: videoPixel.x, y: videoHeight - videoPixel.y)
    }
}
