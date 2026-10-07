//
//  WebCamera.swift
//  Reco
//

import CoreGraphics

/// A web script's camera (spec 0009). A clip that shows an element (``PointerClip/show``) frames
/// that element while it lasts; once any clip does, nothing else zooms, so a script can say "no zoom
/// here". Without any, a hover or click clip with a ``PointerClip/zoom`` magnifies its target, from a
/// little before the action to a little after it. The window previews both; a render hands
/// ``segments(for:telemetry:shots:)`` to the editor, whose camera draws them.
nonisolated enum WebCamera {

    /// The zoom is in place this long before the clip starts, so the action happens zoomed in.
    static let leadIn = 0.4

    /// And stays this long after it ends, so the result can be seen.
    static let hold = 0.6

    /// The scales the inspector offers. 1.5× keeps context; 3× fills the frame with a button.
    static let scales: [Double] = [1.5, 2, 3]

    /// The magnification agents may ask for, and the editor's zoom slider allows.
    static let scaleRange = 1.25...4.0

    /// The most a shown element is magnified: as far as a page rendered at 2× stays sharp. At 1× it's
    /// soft already.
    static let maximumFitScale = 3.0

    /// The share of the view a shown element fills at most, so it has room around it.
    static let fitFill = 0.8

    /// A shown element that needs less magnification than this is nearly the whole view: below it a
    /// zoom is a wobble, not a zoom.
    static let minimumFitScale = 1.1

    /// A zoom that ends less than this before the next one starts is held until then, so the view
    /// pans across instead of zooming out and back in.
    static let panGap = 1.0

    /// Where a show clip's element was when its clip started: the part of it in view, in viewport CSS
    /// pixels.
    struct Shot: Equatable, Sendable {
        var range: Range<Double>
        var visible: CGRect
    }

    /// The least share of a shown element that must be in view for the video to zoom on it.
    static let minimumShownFraction = 0.5

    /// The part of an element at `frame` (viewport CSS pixels) that's in a `viewport`, or `nil` when
    /// that's under ``minimumShownFraction`` of it: framing it would frame something else.
    static func visiblePart(of frame: CGRect, in viewport: CGSize) -> CGRect? {
        let visible = frame.intersection(CGRect(origin: .zero, size: viewport))
        guard !visible.isEmpty, visible.width * visible.height >= minimumShownFraction * frame.width * frame.height else { return nil }
        return visible
    }

    /// Whether `script` zooms on the elements its clips show, rather than on their targets.
    static func showsElements(_ script: WebScript) -> Bool {
        script.pointer.contains { $0.show != nil }
    }

    /// Whether the camera zooms around `clip` of `script`.
    static func zooms(on clip: PointerClip, in script: WebScript) -> Bool {
        showsElements(script) ? clip.show != nil : clip.zoom != nil
    }

    /// The scale and centre that frame `visible` (viewport CSS pixels) in a `viewport`: it fills at
    /// most ``fitFill`` of the view, magnified at most ``maximumFitScale``. The centre is a fraction of
    /// the video, kept where the view stays inside it. `nil` when that's under ``minimumFitScale``.
    static func fit(_ visible: CGRect, in viewport: CGSize) -> (scale: Double, center: CGPoint)? {
        guard visible.width > 0, visible.height > 0 else { return nil }
        let scale = min(maximumFitScale, fitFill * viewport.width / visible.width, fitFill * viewport.height / visible.height)
        guard scale >= minimumFitScale else { return nil }
        let center = CGPoint(x: visible.midX / viewport.width, y: visible.midY / viewport.height)
        return (scale, ZoomSegment.clamped(center, scale: scale))
    }

    /// The show clip playing at `time`.
    static func shownClip(at time: Double, in script: WebScript) -> PointerClip? {
        script.pointer.first { $0.show != nil && $0.range.contains(time) }
    }

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

    /// The editor's zooms for a rendered take: from `shots`, the elements its show clips found, when
    /// it ``showsElements(_:)``, else from its zoomed clips.
    static func segments(for script: WebScript, telemetry: InputTelemetry, shots: [Shot]) -> [ZoomSegment] {
        guard showsElements(script) else { return targetSegments(for: script, telemetry: telemetry) }
        return showSegments(shots, viewport: script.viewport, pageChanges: PageChanges.times(in: telemetry))
    }

    /// One fixed zoom per shot that ``fit(_:in:)`` frames, for its clip's time. One that ends less than
    /// ``panGap`` before the next starts is held until then, and each ends at a page change
    /// (``PageChanges``), so a scroll shows the page whole and a click that opens a page isn't zoomed on.
    static func showSegments(_ shots: [Shot], viewport: CGSize, pageChanges: [Double]) -> [ZoomSegment] {
        var zooms = shots.sorted { $0.range.lowerBound < $1.range.lowerBound }.compactMap { shot in
            fit(shot.visible, in: viewport).map { ZoomSegment(range: shot.range, scale: $0.scale, focus: .fixed(center: $0.center)) }
        }
        for index in zooms.indices.dropLast() where zooms[index + 1].range.lowerBound - zooms[index].range.upperBound < panGap {
            zooms[index].range = zooms[index].range.lowerBound..<zooms[index + 1].range.lowerBound
        }
        return PageChanges.ending(zooms, at: pageChanges).filter { $0.range.upperBound - $0.range.lowerBound >= ZoomSegment.minimumDuration }
    }

    /// One fixed zoom per zoomed clip, centred where the cursor was on its target. Zooms whose windows
    /// meet hand over where the second begins, so the view pans between them instead of zooming out
    /// and back in.
    private static func targetSegments(for script: WebScript, telemetry: InputTelemetry) -> [ZoomSegment] {
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
