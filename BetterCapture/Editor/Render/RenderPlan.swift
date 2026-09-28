//
//  RenderPlan.swift
//  BetterCapture
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
}

// MARK: - Building

extension RenderPlan {

    /// A chip's height as a share of the video's shorter side.
    nonisolated private static let chipHeightFraction = 0.06

    nonisolated private static let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "RenderPlan")

    /// Builds the plan off the main actor.
    /// - Parameter keyLabels: Labels keystrokes; without it, none are shown.
    @concurrent
    static func build(project: EditorProject, source: EditorSource, keyLabels: KeyLabelFormatter?) async -> RenderPlan {
        let signpost = signposter.beginInterval("Build")
        defer { signposter.endInterval("Build", signpost) }

        let videoSize = source.naturalSize
        var clicks: [ClickMarker] = []
        var keystrokes: [KeystrokeChip] = []
        var labels: [String] = []
        if let telemetry = source.telemetry {
            if project.clickHighlights.isEnabled {
                clicks = clickMarkers(for: telemetry, style: project.clickHighlights, videoHeight: videoSize.height)
            }
            if project.keystrokes.isEnabled, let keyLabels {
                (keystrokes, labels) = keystrokeChips(for: telemetry, style: project.keystrokes, keyLabels: keyLabels)
            }
        }

        let ringDiameter = clicks.map(\.diameter).max() ?? 0
        let chipHeight = min(videoSize.width, videoSize.height) * chipHeightFraction
        return RenderPlan(
            timeMap: TimeMap(cuts: project.cuts, sourceDuration: source.duration),
            videoSize: videoSize,
            clicks: clicks,
            clickDuration: project.clickHighlights.duration,
            clickRing: clicks.isEmpty ? .empty() : OverlayImages.ring(diameter: ringDiameter, color: project.clickHighlights.color.cgColor),
            keystrokes: keystrokes,
            chipImages: labels.map { OverlayImages.chip(label: $0, height: chipHeight) }
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

    /// Flips a video pixel (top-left origin, as telemetry maps it) into Core Image space
    /// (bottom-left origin).
    nonisolated static func coreImagePoint(_ videoPixel: CGPoint, videoHeight: CGFloat) -> CGPoint {
        CGPoint(x: videoPixel.x, y: videoHeight - videoPixel.y)
    }
}
