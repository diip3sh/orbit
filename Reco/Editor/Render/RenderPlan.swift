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

    /// How many rings a click draws, and when.
    var clickEffect = ClickHighlightStyle.Effect.circle

    /// Key presses to show, sorted by time. Empty when the overlay is off.
    let keystrokes: [KeystrokeChip]

    /// One image per distinct label, indexed by ``KeystrokeChip/image``.
    let chipImages: [CIImage]

    /// The output frame, and where the video sits on it.
    let canvas: CanvasLayout

    /// What frames are drawn in: the recording's dynamic range, or SDR for a target that doesn't keep
    /// HDR. The overlays' images are already in its encoding.
    let dynamicRange: DynamicRange

    /// Shrinks frames with Core Image's high-quality downsampling, as exports do: a 1080p export of a
    /// Retina recording halves it, and plain linear sampling blurs its text. The preview skips it.
    var downsamplesSmoothly = false

    /// How long the shutter is open over a frame, in seconds: the project's motion blur over the output's
    /// frame rate. 0 draws every frame sharp.
    var shutter = 0.0

    /// The most samples a blurred frame averages. Measured on an M2, Debug, 4K at the peak of a 2× zoom (load
    /// average 5.5): 8 samples took 12.4–14 ms p95, 4 took 9.5 and 2 took 5.6, against 5.2–6.8 unblurred. So the
    /// preview takes 2 to stay in the 8 ms budget and exports, which aren't real time, take 8.
    /// ponytail: fuse the samples into one Metal kernel if the preview's blur should match the export's.
    var maximumBlurSamples = 8

    /// The part of the recording's frames drawn, in their Core Image pixels, or `nil` for all of it. Everything
    /// else in the plan (``videoSize``, positions, the camera) is already of the crop.
    var crop: CGRect?

    /// The masks, sorted and apart.
    var masks: [PlannedMask] = []
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

        let cropPixels = VideoCrop.pixels(of: project.crop, in: source.naturalSize)
        let videoSize = cropPixels.size
        let telemetry = source.telemetry?.cropped(to: cropPixels)
        let dynamicRange = target.keepsHDR ? source.dynamicRange : .sdr
        let timeMap = TimeMap(cuts: project.cuts, speeds: project.speeds, sourceDuration: source.duration, frameRate: source.frameRate)
        // The costliest parts, and independent, so they're built alongside the rest. For 10 minutes
        // with 455 zooms, 3,000 clicks and 12,000 keys (M1, Debug), the camera takes 38 ms and the
        // cursor 35; the plan builds in 42 ms instead of 105
        async let camera = camera(for: project, telemetry: telemetry, timeMap: timeMap)
        async let cursor = telemetry.flatMap {
            drawnCursor(
                for: $0, style: project.cursor, duration: source.duration, videoHeight: videoSize.height, arrow: resources.arrow,
                loop: project.cursor.loops ? cursorLoop(for: timeMap) : nil, stop: cursorStop(before: project.cursor.stopDuration, for: timeMap)
            )
        }
        let canvas = CanvasLayout(style: project.canvas, videoSize: videoSize, shorterSide: target.shorterSide, background: resources.background)
            .encoded(in: dynamicRange)

        var clicks: [ClickMarker] = []
        var keystrokes: [KeystrokeChip] = []
        var labels: [String] = []
        // Rings and chips last their duration on screen whatever the speed, so they're timed on the output
        if let telemetry {
            clicks = outputClickMarkers(for: telemetry, style: project.clickHighlights, videoHeight: videoSize.height, timeMap: timeMap)
            if project.keystrokes.isEnabled, let keyLabels = resources.keyLabels {
                (keystrokes, labels) = keystrokeChips(for: telemetry, style: project.keystrokes, keyLabels: keyLabels)
                keystrokes = keystrokes.compactMap { chip in timeMap.outputTime(ifKept: chip.time).map { KeystrokeChip(time: $0, image: chip.image) } }
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
            clickRing: clicks.isEmpty ? .empty() : OverlayImages.encoded(
                OverlayImages.ring(diameter: ringDiameter, color: project.clickHighlights.color.cgColor, filled: project.clickHighlights.effect == .circle),
                in: dynamicRange
            ),
            clickEffect: project.clickHighlights.effect,
            keystrokes: keystrokes,
            chipImages: labels.map { OverlayImages.encoded(OverlayImages.chip(label: $0, height: chipHeight), in: dynamicRange) },
            canvas: canvas,
            dynamicRange: dynamicRange,
            downsamplesSmoothly: target.shorterSide != nil,
            shutter: project.motionBlur / (target.frameRate ?? source.frameRate), maximumBlurSamples: target.shorterSide == nil ? 2 : 8,
            crop: videoSize == source.naturalSize ? nil : VideoCrop.coreImageRect(cropPixels, videoHeight: source.naturalSize.height),
            masks: PlannedMask.planned(project.masks, videoSize: videoSize)
        )
    }

    /// The presses to highlight at their output times, none when highlights are off: rings last their duration on
    /// screen whatever the speed.
    nonisolated static func outputClickMarkers(
        for telemetry: InputTelemetry, style: ClickHighlightStyle, videoHeight: CGFloat, timeMap: TimeMap
    ) -> [ClickMarker] {
        guard style.effect != .off else { return [] }
        return clickMarkers(for: telemetry, style: style, videoHeight: videoHeight).compactMap { marker in
            timeMap.outputTime(ifKept: marker.time).map { ClickMarker(time: $0, position: marker.position, diameter: marker.diameter) }
        }
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
        loop: CursorPath.Loop? = nil, stop: Double? = nil
    ) -> (path: CursorPath, shapes: CursorShapeTrack)? {
        guard !telemetry.capture.cursorInVideo, style.isEnabled,
              let path = CursorPath(telemetry: telemetry, style: style, duration: duration, videoHeight: videoHeight, loop: loop, stop: stop)
        else { return nil }
        // The images are drawn once, here, whatever the appearance
        let shapes = switch style.appearance {
        case .recorded: CursorShapeTrack(telemetry: telemetry, duration: duration, arrow: arrow, arrowOnly: style.alwaysUsesArrow)
        case .white: CursorShapeTrack(sprite: OverlayImages.whiteArrow())
        case .dot: CursorShapeTrack(sprite: OverlayImages.dot())
        }
        return (path, shapes)
    }

    /// What makes the cursor loop: it ends the last frame where the first one has it, gliding there over the last
    /// second of output (less when the last kept range is shorter, since the glide stays inside it).
    nonisolated static func cursorLoop(for timeMap: TimeMap) -> CursorPath.Loop {
        let frames = FrameGrid(frameRate: timeMap.frameRate, duration: timeMap.outputDuration)
        let last = frames.time(ofFrame: frames.lastFrame)
        let end = timeMap.sourceTime(atOutput: last)
        let rangeStart = timeMap.keptRanges.last?.lowerBound ?? 0
        let glideStart = max(timeMap.sourceTime(atOutput: last - CursorPath.loopDuration), rangeStart)
        return CursorPath.Loop(start: timeMap.sourceTime(atOutput: 0), glide: glideStart..<end)
    }

    /// The source time from which the cursor holds still: `duration` seconds of output before the last frame, or
    /// `nil` when it never stops. With Loop Position on as well, the cursor glides back in the last second after it.
    nonisolated static func cursorStop(before duration: Double, for timeMap: TimeMap) -> Double? {
        guard duration > 0 else { return nil }
        let frames = FrameGrid(frameRate: timeMap.frameRate, duration: timeMap.outputDuration)
        return timeMap.sourceTime(atOutput: max(frames.time(ofFrame: frames.lastFrame) - duration, 0))
    }

    /// The camera, moving on output time, so a zoom eases in at the same pace in a fast part, and across a cut
    /// instead of jumping.
    nonisolated static func camera(for project: EditorProject, telemetry: InputTelemetry?, timeMap: TimeMap) -> CameraPath {
        CameraPath(
            zooms: outputZooms(project.zooms, timeMap: timeMap),
            cursor: telemetry.map { cursorPoints(for: $0, during: project.zooms).map { (timeMap.outputTime(atSource: $0.time), $0.point) } } ?? [],
            duration: timeMap.outputDuration,
            stiffness: project.zoomMotion.frequency
        )
    }

    /// The zooms on output time, for the camera; a zoom entirely cut is left out.
    nonisolated static func outputZooms(_ zooms: [ZoomSegment], timeMap: TimeMap) -> [ZoomSegment] {
        zooms.compactMap { zoom in
            var output = zoom
            output.range = timeMap.outputTime(atSource: zoom.range.lowerBound)..<timeMap.outputTime(atSource: zoom.range.upperBound)
            return output.range.isEmpty ? nil : output
        }
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
