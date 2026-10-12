//
//  TimelineViewport.swift
//  Reco
//

import Foundation

/// Which part of the recording the timeline shows: at zoom 1 the whole of it, past that a window
/// `duration / zoom` long starting at `start`. Pure: the timeline view and the ruler read times and
/// points off it, the toolbar's zoom controls and the scroll gestures move it.
nonisolated struct TimelineViewport: Equatable, Sendable {

    /// The recording's length in seconds.
    var duration: Double

    /// 1 shows the whole recording; the visible window is `duration / zoom`.
    var zoom = 1.0

    /// The visible window's left edge, in source seconds.
    var start = 0.0

    /// The deepest zoom, so a second of the recording still spans a few points.
    static let maximumZoom = 16.0

    /// The visible window's length in seconds.
    var visible: Double {
        duration > 0 ? min(duration / zoom, duration) : 0
    }

    /// The visible window's right edge, in source seconds.
    var end: Double {
        start + visible
    }

    /// Whether the whole recording is on screen: no scrolling, no scroll indicator.
    var showsAll: Bool {
        zoom <= 1
    }

    init(duration: Double) {
        self.duration = duration
    }

    /// The source time at `point` points into a `width`-point timeline.
    func time(atX point: CGFloat, width: CGFloat) -> Double {
        guard width > 0, visible > 0 else { return start }
        return start + Double(point) / Double(width) * visible
    }

    /// Where `time` falls in a `width`-point timeline, in points; off the ends when it's outside.
    func x(at time: Double, width: CGFloat) -> CGFloat {
        guard visible > 0 else { return 0 }
        return CGFloat((time - start) / visible) * width
    }

    /// Sets the zoom, keeping `anchor` (a source time) where it is on screen.
    mutating func zoom(to newZoom: Double, anchor: Double) {
        let newZoom = min(max(newZoom, 1), Self.maximumZoom)
        let fraction = visible > 0 ? (anchor - start) / visible : 0.5
        zoom = newZoom
        start = Self.clampedStart(anchor - fraction * visible, duration: duration, visible: visible)
    }

    /// Moves the window by `delta` seconds, clamped to the recording.
    mutating func scroll(by delta: Double) {
        start = Self.clampedStart(start + delta, duration: duration, visible: visible)
    }

    /// Moves the window so `time` sits `fraction` of the way across it.
    mutating func scroll(toShow time: Double, at fraction: Double) {
        start = Self.clampedStart(time - fraction * visible, duration: duration, visible: visible)
    }

    /// Back to the whole recording.
    mutating func showAll() {
        zoom = 1
        start = 0
    }

    /// A new recording length (another take, a trim): keep the zoom, clamp the window.
    mutating func setDuration(_ newDuration: Double) {
        duration = newDuration
        start = Self.clampedStart(start, duration: newDuration, visible: visible)
    }

    private static func clampedStart(_ start: Double, duration: Double, visible: Double) -> Double {
        min(max(start, 0), max(duration - visible, 0))
    }
}
