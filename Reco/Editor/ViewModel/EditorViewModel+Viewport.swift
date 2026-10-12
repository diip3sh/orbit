//
//  EditorViewModel+Viewport.swift
//  Reco
//

import Foundation

extension EditorViewModel {

    /// Zooms the timeline in (`factor` over 1) or out, keeping the playhead where it is on screen,
    /// or the middle when the playhead isn't showing — or holding `anchor` still when one is given.
    func zoomTimeline(by factor: Double, anchor: Double? = nil) {
        setTimelineZoom(viewport.zoom * factor, anchor: anchor)
    }

    /// Sets the timeline's zoom, anchored like ``zoomTimeline(by:)`` unless an anchor is given
    /// (a ⌘-scroll holds the time under the pointer still).
    func setTimelineZoom(_ zoom: Double, anchor: Double? = nil) {
        viewport.zoom(to: zoom, anchor: anchor ?? timelineZoomAnchor)
    }

    /// Scrolls the timeline by `delta` source seconds.
    func scrollTimeline(by delta: Double) {
        viewport.scroll(by: delta)
    }

    /// Puts the visible window's left edge at `start` source seconds (the scroll indicator's drag).
    func setTimelineStart(_ start: Double) {
        viewport.scroll(by: start - viewport.start)
    }

    /// Back to the whole recording.
    func showWholeRecording() {
        viewport.showAll()
    }

    /// During playback, scrolls the window when the playhead leaves it, so it re-enters a little in
    /// from the left. Called from the playhead's tick, so it costs nothing while paused.
    func keepPlayheadVisible() {
        guard playback.isPlaying else { return }
        let playhead = playheadSourceTime
        guard playhead < viewport.start || playhead > viewport.end else { return }
        viewport.scroll(toShow: playhead, at: 0.1)
    }

    /// Where a zoom holds still: the playhead when it's on screen, the window's middle otherwise.
    private var timelineZoomAnchor: Double {
        let playhead = playheadSourceTime
        return playhead >= viewport.start && playhead <= viewport.end ? playhead : (viewport.start + viewport.end) / 2
    }
}
