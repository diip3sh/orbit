//
//  AutoZoomGenerator.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Foundation

/// Zooms in where the user was working: on bursts of clicks, typing, places the cursor moved to
/// and rested at, and things it circled, close together in time and on screen. A pure function of
/// the telemetry.
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

        /// How long, in seconds, the cursor must stay put after moving for its stop to count; it
        /// passes through places faster.
        var restDuration = 0.5

        /// How far the cursor may drift while it rests, as a share of the video.
        var restRadius = 0.02

        /// How far from where it last rested the cursor must stop for the stop to count, as a
        /// share of the video, so nudges and a resting cursor don't zoom.
        var restTravel = 0.15

        /// How far apart, as a share of the video, the points are that circling is followed by, so
        /// drift doesn't turn it. Real circling measured 40–110 pt across, a turn every 0.3–0.5 s.
        var circleStep = 0.01

        /// The sharpest turn, in radians, from one step of circling to the next. The ends of real,
        /// oval loops turn up to about 3π/4; shaking the cursor reverses it, turning by about π.
        var sharpestCircleTurn = 0.75 * Double.pi

        /// How near where it started a turn must end, as a share of its size, to be a circle rather
        /// than a curve; real circling drifts a little each turn. At 0.75 and above, the curve
        /// leading into real circling joined it and moved its centre; 0.25 finds the same circles.
        var circleClosure = 0.5

        /// Whether a zoom on a rest lasts as long as the cursor stays, rather than from its arrival,
        /// and ends ``scrollHold`` after the page starts to scroll under it or is replaced.
        var holdsRests = false

        /// How long a held rest's zoom lasts once the page scrolls: about how long the spring takes
        /// to start moving out, so the scroll shows the page at full size.
        var scrollHold = 0.3
    }

    /// The automatic zooms for a recording, sorted and apart.
    /// - Parameter duration: The recording's length in seconds.
    /// - Parameter configuration: By default, ``Configuration/init(for:)``.
    static func segments(for telemetry: InputTelemetry, duration: Double, configuration: Configuration? = nil) -> [ZoomSegment] {
        let configuration = configuration ?? Configuration(for: telemetry)
        let reach = configuration.usableFraction / configuration.scale
        let fits = { (group: Group) in group.bounds.width <= reach && group.bounds.height <= reach }
        // A page a click opens shows whole, like a page that scrolls: the zoom on the click ends
        let scrolls = (scrollStarts(in: telemetry) + telemetry.navigations.map(\.time)).sorted()

        var groups: [Group] = []
        let stops = rests(in: telemetry, duration: duration, configuration: configuration).map { rest in
            var group = Group((rest.time, rest.point))
            if configuration.holdsRests {
                group.end = min(rest.end, firstScroll(in: scrolls, after: rest.time) ?? rest.end)
            }
            return group
        }
        let events = activity(in: telemetry).map(Group.init) + stops + circles(in: telemetry, configuration: configuration).map(Group.init)
        // Held rests aren't zoomed on across a scroll: the page moved between them
        let scrolledBetween = { (group: Group, event: Group) in
            configuration.holdsRests && firstScroll(in: scrolls, after: group.start).map { $0 <= event.start } == true
        }
        for event in events.sorted(by: { $0.start < $1.start }) {
            if let last = groups.last, event.start - last.end < configuration.maximumGap, fits(last.merging(event)), !scrolledBetween(last, event) {
                groups[groups.count - 1] = last.merging(event)
            } else {
                groups.append(event)
            }
        }

        var zooms: [(group: Group, range: Range<Double>)] = []
        for group in groups {
            guard var range = range(of: group, duration: duration, configuration: configuration) else { continue }
            if configuration.holdsRests, let scroll = firstScroll(in: scrolls, after: group.start) {
                // Not shorter than half the minimum, for a scroll that starts as the cursor arrives
                range = range.lowerBound..<min(range.upperBound, max(scroll + configuration.scrollHold, range.lowerBound + configuration.minimumDuration / 2))
            }
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

    /// A place the cursor stopped at: from when it arrived to when it left, as a fraction of the video.
    nonisolated struct Rest: Equatable, Sendable {
        var time: Double
        var point: CGPoint
        var end: Double
    }

    /// Where the cursor came to rest inside the video after moving there: the user is about to
    /// click or is pointing something out. Timed when it arrived, with when it left.
    static func rests(in telemetry: InputTelemetry, duration: Double, configuration: Configuration = Configuration()) -> [Rest] {
        let samples = telemetry.cursor.compactMap { sample in
            telemetry.normalizedVideoPoint(for: sample.location, at: sample.time).map { (time: sample.time, point: $0) }
        }

        var rests: [Rest] = []
        var lastRest = samples.first?.point
        var index = samples.startIndex
        while index < samples.endIndex {
            let arrival = samples[index]
            // Samples are stored only on change, so the cursor stays until one leaves the radius
            let departure = samples[(index + 1)...].firstIndex { distance($0.point, arrival.point) > configuration.restRadius } ?? samples.endIndex
            let leaves = departure < samples.endIndex ? samples[departure].time : duration
            guard leaves - arrival.time >= configuration.restDuration else {
                index += 1
                continue
            }
            if let lastRest, distance(arrival.point, lastRest) >= configuration.restTravel,
               (0...1).contains(arrival.point.x), (0...1).contains(arrival.point.y) {
                rests.append(Rest(time: arrival.time, point: arrival.point, end: leaves))
            }
            lastRest = arrival.point
            index = departure
        }
        return rests
    }

    /// Where the cursor circled something inside the video: it turned all the way round within one
    /// view, without stopping or reversing, and came back near where it started. The user is
    /// pointing it out. Each further turn is another circle.
    static func circles(in telemetry: InputTelemetry, configuration: Configuration = Configuration()) -> [(range: ClosedRange<Double>, bounds: CGRect)] {
        let path = telemetry.cursor.reduce(into: [(time: Double, point: CGPoint)]()) { path, sample in
            guard let point = telemetry.normalizedVideoPoint(for: sample.location, at: sample.time),
                  path.last.map({ distance(point, $0.point) >= configuration.circleStep }) ?? true else { return }
            path.append((sample.time, point))
        }
        let reach = configuration.usableFraction / configuration.scale
        // How the path changes direction at each point; not at its ends
        let turns = path.indices.map { $0 > 0 && $0 + 1 < path.count ? turn(path[$0 - 1].point, path[$0].point, path[$0 + 1].point) : 0 }
        let bounds = { (stretch: ClosedRange<Int>) in path[stretch].reduce(CGRect.null) { $0.union(CGRect(origin: $1.point, size: .zero)) } }
        let comesBack = { (stretch: ClosedRange<Int>, bounds: CGRect) in
            distance(path[stretch.upperBound].point, path[stretch.lowerBound].point) <= configuration.circleClosure * max(bounds.width, bounds.height)
        }

        var circles: [(range: ClosedRange<Double>, bounds: CGRect)] = []
        var start = path.startIndex
        search: while start + 2 < path.endIndex {
            var turned = 0.0
            var extent = CGRect(origin: path[start].point, size: .zero)
            for end in (start + 1)..<path.endIndex {
                extent = extent.union(CGRect(origin: path[end].point, size: .zero))
                guard path[end].time - path[end - 1].time < configuration.restDuration, extent.width <= reach, extent.height <= reach else { break }
                if end - start >= 2 {
                    let angle = turns[end - 1]
                    guard abs(angle) <= configuration.sharpestCircleTurn else { break }
                    turned += angle
                }
                guard abs(turned) >= 2 * .pi, comesBack(start...end, extent) else { continue }

                // Without the move into it: the shortest stretch ending here that still comes full circle
                var first = start
                var circle = extent
                while first + 2 < end, abs(turned - turns[first + 1]) >= 2 * .pi {
                    let shorter = bounds((first + 1)...end)
                    guard comesBack((first + 1)...end, shorter) else { break }
                    turned -= turns[first + 1]
                    first += 1
                    circle = shorter
                }
                if (0...1).contains(circle.midX), (0...1).contains(circle.midY) {
                    circles.append((path[first].time...path[end].time, circle))
                }
                start = end
                continue search
            }
            start += 1
        }
        return circles
    }

    // MARK: - Private

    /// When each scroll started: its first event after a pause longer than ``scrollPause``.
    private static func scrollStarts(in telemetry: InputTelemetry) -> [Double] {
        zip([-Double.infinity] + telemetry.scrolls.map(\.time), telemetry.scrolls.map(\.time)).compactMap { previous, time in
            time - previous > scrollPause ? time : nil
        }
    }

    /// The longest pause between a scroll's events: web takes have one every frame, wheels a few
    /// times a second.
    private static let scrollPause = 0.25

    /// The first of the sorted scroll `starts` after `time`; one at `time` brought the cursor there.
    private static func firstScroll(in starts: [Double], after time: Double) -> Double? {
        let index = starts.partitioningIndex { $0 > time }
        return index < starts.count ? starts[index] : nil
    }

    private static func distance(_ start: CGPoint, _ end: CGPoint) -> Double {
        hypot(start.x - end.x, start.y - end.y)
    }

    /// The signed angle, in radians, by which the path from `first` through `second` to `third`
    /// changes direction at `second`.
    private static func turn(_ first: CGPoint, _ second: CGPoint, _ third: CGPoint) -> Double {
        let (dx1, dy1) = (second.x - first.x, second.y - first.y)
        let (dx2, dy2) = (third.x - second.x, third.y - second.y)
        return atan2(dx1 * dy2 - dy1 * dx2, dx1 * dx2 + dy1 * dy2)
    }

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

        /// A circle, counted once at its middle.
        init(_ circle: (range: ClosedRange<Double>, bounds: CGRect)) {
            start = circle.range.lowerBound
            end = circle.range.upperBound
            bounds = circle.bounds
            total = CGPoint(x: circle.bounds.midX, y: circle.bounds.midY)
            count = 1
        }

        var centroid: CGPoint {
            CGPoint(x: total.x / CGFloat(count), y: total.y / CGFloat(count))
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

nonisolated extension AutoZoomGenerator.Configuration {

    /// The defaults for `telemetry`'s kind of recording. A web take's cursor stops only where its
    /// script points at something (spec 0005), so each stop counts and is zoomed on while it lasts.
    init(for telemetry: InputTelemetry) {
        self.init()
        if telemetry.capture.kind == .web {
            holdsRests = true
            restTravel = restRadius
        }
    }
}
