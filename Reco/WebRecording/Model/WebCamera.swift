//
//  WebCamera.swift
//  Reco
//

import CoreGraphics

/// A web script's camera (spec 0009): a hover or click clip with a ``PointerClip/zoom`` magnifies its
/// target, from a little before the action to a little after it. The window previews it from
/// ``zoom(at:in:)``; a render hands ``segments(for:telemetry:)`` to the editor, whose camera draws it.
nonisolated enum WebCamera {

    /// The zoom is in place this long before the clip starts, so the action happens zoomed in.
    static let leadIn = 0.4

    /// And stays this long after it ends, so the result can be seen.
    static let hold = 0.6

    /// The scales the inspector offers. 1.5× keeps context; 3× fills the frame with a button.
    static let scales: [Double] = [1.5, 2, 3]

    /// The magnification agents may ask for, and the editor's zoom slider allows.
    static let scaleRange = 1.25...4.0

    /// When `clip`'s zoom is in effect, within a take of `duration` seconds.
    static func window(of clip: PointerClip, duration: Double) -> Range<Double> {
        let start = max(0, clip.range.lowerBound - leadIn)
        return start..<max(start, min(duration, clip.range.upperBound + hold))
    }

    /// The zoom in effect at `time`, and the clip it belongs to.
    static func zoom(at time: Double, in script: WebScript) -> (scale: Double, clip: PointerClip)? {
        for clip in script.pointer {
            if let scale = clip.zoom, window(of: clip, duration: script.duration).contains(time) {
                return (scale, clip)
            }
        }
        return nil
    }

    /// The editor's zooms for a rendered take: one fixed zoom per zoomed clip, centred where the cursor
    /// was on its target. Zooms whose windows meet hand over where the second begins, so the view pans
    /// between them instead of zooming out and back in.
    static func segments(for script: WebScript, telemetry: InputTelemetry) -> [ZoomSegment] {
        var segments: [ZoomSegment] = []
        for clip in script.pointer.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            guard let scale = clip.zoom else { continue }
            var range = window(of: clip, duration: script.duration)
            if let previous = segments.last, range.lowerBound < previous.range.upperBound {
                let handover = max(previous.range.lowerBound + ZoomSegment.minimumDuration, range.lowerBound)
                guard range.upperBound - handover >= ZoomSegment.minimumDuration else { continue }
                segments[segments.count - 1].range = previous.range.lowerBound..<handover
                range = handover..<range.upperBound
            }
            guard range.upperBound - range.lowerBound >= ZoomSegment.minimumDuration else { continue }
            let middle = (clip.range.lowerBound + clip.range.upperBound) / 2
            let location = telemetry.cursor.last { $0.time <= middle }?.location ?? clip.target.point
            let center = CGPoint(x: location.x / script.viewport.width, y: location.y / script.viewport.height)
            segments.append(ZoomSegment(range: range, scale: scale, focus: .fixed(center: ZoomSegment.clamped(center, scale: scale))))
        }
        return segments
    }
}
