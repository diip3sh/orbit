//
//  AutoZoomGenerator.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Foundation

/// Zooms in where the user was working: on bursts of clicks and typing close together in time and
/// on screen. A pure function of the telemetry.
nonisolated enum AutoZoomGenerator {

    nonisolated struct Configuration: Sendable {
        var scale = 2.0

        /// Events further apart than this, in seconds, start a new zoom.
        var maximumGap = 2.0

        /// How long before its first event a zoom starts, so the view has zoomed in by then.
        var leadTime = 0.5

        /// How long after its last event a zoom lasts.
        var holdTime = 1.5

        var minimumDuration = 1.5

        /// Zooms closer than this, in seconds, become one; when their events don't fit one view,
        /// the first ends where the second starts, so the view pans across without zooming out.
        var mergeGap = 1.0

        /// The share of the magnified view a zoom's events must fit in, so none sits at its edge.
        var usableFraction = 0.8
    }

    /// The automatic zooms for a recording, sorted and apart.
    /// - Parameter duration: The recording's length in seconds.
    static func segments(for telemetry: InputTelemetry, duration: Double, configuration: Configuration = Configuration()) -> [ZoomSegment] {
        let reach = configuration.usableFraction / configuration.scale
        let fits = { (group: Group) in group.bounds.width <= reach && group.bounds.height <= reach }

        var groups: [Group] = []
        for event in activity(in: telemetry) {
            if let last = groups.last, event.time - last.end < configuration.maximumGap, fits(last.adding(event)) {
                groups[groups.count - 1] = last.adding(event)
            } else {
                groups.append(Group(event))
            }
        }

        var zooms: [(group: Group, range: Range<Double>)] = []
        for group in groups {
            guard let range = range(of: group, duration: duration, configuration: configuration) else { continue }
            guard let previous = zooms.last, range.lowerBound - previous.range.upperBound < configuration.mergeGap else {
                zooms.append((group, range))
                continue
            }
            let merged = previous.group.merging(group)
            if fits(merged) {
                zooms[zooms.count - 1] = (merged, previous.range.lowerBound..<max(previous.range.upperBound, range.upperBound))
            } else {
                // Between their events, at the latest where the second would start anyway
                let boundary = max(range.lowerBound, (previous.group.end + group.start) / 2)
                zooms[zooms.count - 1].range = previous.range.lowerBound..<boundary
                zooms.append((group, boundary..<range.upperBound))
            }
        }

        return zooms.map { zoom in
            ZoomSegment(
                range: zoom.range,
                scale: configuration.scale,
                focus: .fixed(center: ZoomSegment.clamped(zoom.group.centroid, scale: configuration.scale)),
                isAutomatic: true
            )
        }
    }

    /// Presses inside the video, in time order: clicks where they were, keys at the last click.
    static func activity(in telemetry: InputTelemetry) -> [(time: Double, point: CGPoint)] {
        // Clicks first: the sort is stable, so a click comes before a key pressed at the same time
        let presses: [(time: Double, click: CGPoint?)] = telemetry.clicks.filter(\.isDown).map { ($0.time, $0.location) }
            + telemetry.keys.filter { !$0.isRepeat }.map { ($0.time, nil) }
        var activity: [(time: Double, point: CGPoint)] = []
        var lastClick: CGPoint?
        for press in presses.sorted(by: { $0.time < $1.time }) {
            if let location = press.click {
                lastClick = telemetry.normalizedVideoPoint(for: location, at: press.time).flatMap { point in
                    (0...1).contains(point.x) && (0...1).contains(point.y) ? point : nil
                }
            }
            if let lastClick {
                activity.append((press.time, lastClick))
            }
        }
        return activity
    }

    // MARK: - Private

    /// A zoom's range: its events plus lead and hold time, inside the recording and at least the
    /// minimum long where the recording allows. `nil` for an empty recording.
    private static func range(of group: Group, duration: Double, configuration: Configuration) -> Range<Double>? {
        var start = max(group.start - configuration.leadTime, 0)
        var end = min(group.end + configuration.holdTime, duration)
        if end - start < configuration.minimumDuration {
            start = max(min(start, end - configuration.minimumDuration), 0)
            end = min(max(end, start + configuration.minimumDuration), duration)
        }
        return start < end ? start..<end : nil
    }

    /// Events zoomed on together.
    private struct Group {
        var start: Double
        var end: Double

        /// Around every event's point.
        var bounds: CGRect

        private var total: CGPoint
        private var count: Int

        init(_ event: (time: Double, point: CGPoint)) {
            start = event.time
            end = event.time
            bounds = CGRect(origin: event.point, size: .zero)
            total = event.point
            count = 1
        }

        var centroid: CGPoint {
            CGPoint(x: total.x / CGFloat(count), y: total.y / CGFloat(count))
        }

        func adding(_ event: (time: Double, point: CGPoint)) -> Group {
            merging(Group(event))
        }

        func merging(_ other: Group) -> Group {
            var group = self
            group.start = min(start, other.start)
            group.end = max(end, other.end)
            group.bounds = bounds.union(other.bounds)
            group.total = CGPoint(x: total.x + other.total.x, y: total.y + other.total.y)
            group.count += other.count
            return group
        }
    }
}
