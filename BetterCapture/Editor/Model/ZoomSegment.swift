//
//  ZoomSegment.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Foundation

/// A part of the recording shown magnified. The camera starts zooming in at its start and back out
/// at its end. Times are source seconds.
nonisolated struct ZoomSegment: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var range: Range<Double>

    /// How much the content is magnified, e.g. 2 for twice its size.
    var scale = 2.0

    var focus: Focus

    /// Made by auto-zoom, which replaces it when regenerating. Editing it makes it manual.
    var isAutomatic = false

    /// What the magnified view is centred on.
    nonisolated enum Focus: Codable, Equatable, Sendable {

        /// The cursor. The view moves only when the cursor leaves its middle.
        case followCursor

        /// A fixed point, as fractions of the video's width and height from its top-left corner.
        case fixed(center: CGPoint)
    }

    /// Whether ``focus`` follows the cursor, for a picker. Fixing it centres it on the frame.
    var followsCursor: Bool {
        get { focus == .followCursor }
        set { focus = newValue ? .followCursor : .fixed(center: CGPoint(x: 0.5, y: 0.5)) }
    }

    /// The fixed focus, or `nil` when following the cursor. Set, it's moved to where the view stays
    /// inside the frame.
    var fixedCenter: CGPoint? {
        get {
            guard case .fixed(let center) = focus else { return nil }
            return center
        }
        set {
            focus = newValue.map { .fixed(center: Self.clamped($0, scale: scale)) } ?? .followCursor
        }
    }

    /// The segments the timeline accepts are at least this long, in seconds.
    static let minimumDuration = 0.5

    /// A zoom added by hand lasts this long, if there's room.
    static let defaultDuration = 3.0

    /// The centre nearest `center` at which a view magnified `scale` times stays inside the frame.
    /// Both are fractions of the video's width and height from its top-left corner.
    static func clamped(_ center: CGPoint, scale: Double) -> CGPoint {
        let margin = 0.5 / max(scale, 1)
        return CGPoint(x: min(max(center.x, margin), 1 - margin), y: min(max(center.y, margin), 1 - margin))
    }
}

// MARK: - Editing

/// Every operation keeps the segments sorted and apart, and makes the one it changes manual.
nonisolated extension [ZoomSegment] {

    /// A manual segment starting at `time` and lasting ``ZoomSegment/defaultDuration``, or less up to
    /// the next segment or `duration`. `nil` when there isn't room for ``ZoomSegment/minimumDuration``.
    func newZoom(at time: Double, focus: ZoomSegment.Focus, duration: Double) -> ZoomSegment? {
        guard !contains(where: { $0.range.contains(time) }) else { return nil }
        let end = Swift.min(time + ZoomSegment.defaultDuration, first { $0.range.lowerBound > time }?.range.lowerBound ?? duration, duration)
        guard end - time >= ZoomSegment.minimumDuration else { return nil }
        return ZoomSegment(range: time..<end, focus: focus)
    }

    /// The segments with `zoom`, which must not overlap them, in its place.
    func inserting(_ zoom: ZoomSegment) -> [ZoomSegment] {
        (self + [zoom]).sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// The segments with `zoom` replaced, e.g. with a new scale or focus.
    func replacing(_ zoom: ZoomSegment) -> [ZoomSegment] {
        guard let index = firstIndex(where: { $0.id == zoom.id }) else { return self }
        return updating(index) { $0 = zoom }
    }

    func removing(_ id: ZoomSegment.ID) -> [ZoomSegment] {
        filter { $0.id != id }
    }

    /// The segments with `id` moved by `offset` seconds, stopping at its neighbours and the
    /// recording's ends.
    func moving(_ id: ZoomSegment.ID, by offset: Double, duration: Double) -> [ZoomSegment] {
        guard let index = firstIndex(where: { $0.id == id }) else { return self }
        let range = self[index].range
        let earliest = index > 0 ? self[index - 1].range.upperBound : 0
        let latest = index + 1 < count ? self[index + 1].range.lowerBound : duration
        let start = Swift.min(Swift.max(range.lowerBound + offset, earliest), latest - (range.upperBound - range.lowerBound))
        return updating(index) { $0.range = start..<start + range.upperBound - range.lowerBound }
    }

    /// The segments with `id` starting at `time` instead, stopping at the previous segment and
    /// keeping ``ZoomSegment/minimumDuration``.
    func movingStart(of id: ZoomSegment.ID, to time: Double) -> [ZoomSegment] {
        guard let index = firstIndex(where: { $0.id == id }) else { return self }
        let range = self[index].range
        let earliest = index > 0 ? self[index - 1].range.upperBound : 0
        let start = Swift.max(Swift.min(time, range.upperBound - ZoomSegment.minimumDuration), earliest)
        return updating(index) { $0.range = start..<range.upperBound }
    }

    /// The segments with `id` ending at `time` instead, stopping at the next segment or the
    /// recording's end and keeping ``ZoomSegment/minimumDuration``.
    func movingEnd(of id: ZoomSegment.ID, to time: Double, duration: Double) -> [ZoomSegment] {
        guard let index = firstIndex(where: { $0.id == id }) else { return self }
        let range = self[index].range
        let latest = index + 1 < count ? self[index + 1].range.lowerBound : duration
        let end = Swift.min(Swift.max(time, range.lowerBound + ZoomSegment.minimumDuration), latest)
        return updating(index) { $0.range = range.lowerBound..<end }
    }

    /// The manual segments, plus the automatic ones in `generated` that don't overlap them.
    func regenerated(with generated: [ZoomSegment]) -> [ZoomSegment] {
        let kept = filter { !$0.isAutomatic }
        let added = generated.filter { zoom in !kept.contains { $0.range.overlaps(zoom.range) } }
        return (kept + added).sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    // MARK: Private

    private func updating(_ index: Int, _ change: (inout ZoomSegment) -> Void) -> [ZoomSegment] {
        var segments = self
        change(&segments[index])
        segments[index].isAutomatic = false
        return segments
    }
}
