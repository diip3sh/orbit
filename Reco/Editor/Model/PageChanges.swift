//
//  PageChanges.swift
//  Reco
//

/// When a web take's page started to scroll or was replaced, and the one rule for the zooms around
/// that: a zoom ends ``hold`` after the page starts to change under it, and one the page changes
/// under within ``leadTime`` of its start isn't made at all.
nonisolated enum PageChanges {

    /// How long a zoom lasts once the page starts to change: about how long the camera's spring takes
    /// to start moving out, so a scroll shows the page at full size instead of a magnified blur sliding past.
    static let hold = 0.3

    /// How long the camera takes to zoom in: its spring finishes 96% of a move in 0.5 s. A zoom the page
    /// changes under sooner would zoom in and straight back out, a visible jolt.
    static let leadTime = 0.5

    /// The longest pause between one scroll's events: a web take has one every frame while it scrolls.
    static let scrollPause = 0.25

    /// When the page started to scroll (its first event after a pause longer than ``scrollPause``) or
    /// was replaced, in time order.
    static func times(in telemetry: InputTelemetry) -> [Double] {
        let scrolls = telemetry.scrolls.map(\.time)
        let starts = zip([-Double.infinity] + scrolls, scrolls).compactMap { previous, time in
            time - previous > scrollPause ? time : nil
        }
        return (starts + telemetry.navigations.map(\.time)).sorted()
    }

    /// `zooms`, each ending ``hold`` after the first of the sorted `changes` from its start, without
    /// those a change comes within ``leadTime`` of the start of.
    static func ending(_ zooms: [ZoomSegment], at changes: [Double]) -> [ZoomSegment] {
        zooms.compactMap { zoom in
            let index = changes.partitioningIndex { $0 >= zoom.range.lowerBound }
            guard index < changes.count, changes[index] < zoom.range.upperBound else { return zoom }
            guard changes[index] - zoom.range.lowerBound >= leadTime else { return nil }
            var zoom = zoom
            zoom.range = zoom.range.lowerBound..<min(zoom.range.upperBound, changes[index] + hold)
            return zoom
        }
    }
}
