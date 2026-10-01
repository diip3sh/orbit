//
//  TimelineClip.swift
//  Reco
//

import Foundation

/// Something that spans a while on a timeline lane, like a zoom or a web script's scroll. A lane's
/// clips are sorted and apart; every operation here keeps them so.
nonisolated protocol TimelineClip: Identifiable where ID == UUID {
    var range: Range<Double> { get set }

    /// The shortest a clip can be made, in seconds.
    static var minimumDuration: Double { get }

    /// Called on a clip an operation changed, e.g. to mark an automatic zoom as manual.
    mutating func didEdit()
}

nonisolated extension TimelineClip {
    mutating func didEdit() {}
}

nonisolated extension Array where Element: TimelineClip {

    /// Where a clip starting at `time` fits: `length` long, or less up to the next clip or
    /// `duration`. `nil` inside a clip or when there isn't room for the minimum duration.
    func room(at time: Double, length: Double, duration: Double) -> Range<Double>? {
        guard !contains(where: { $0.range.contains(time) }) else { return nil }
        let end = Swift.min(time + length, first { $0.range.lowerBound > time }?.range.lowerBound ?? duration, duration)
        guard end - time >= Element.minimumDuration else { return nil }
        return time..<end
    }

    /// The clips with `clip`, which must not overlap them, in its place.
    func inserting(_ clip: Element) -> [Element] {
        (self + [clip]).sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// The clips with `clip` replacing the one with its id.
    func replacing(_ clip: Element) -> [Element] {
        guard let index = firstIndex(where: { $0.id == clip.id }) else { return self }
        return updating(index) { $0 = clip }
    }

    func removing(_ id: UUID) -> [Element] {
        filter { $0.id != id }
    }

    /// The clips with `id` moved by `offset` seconds, stopping at its neighbours and the lane's ends.
    func moving(_ id: UUID, by offset: Double, duration: Double) -> [Element] {
        guard let index = firstIndex(where: { $0.id == id }) else { return self }
        let range = self[index].range
        let earliest = index > 0 ? self[index - 1].range.upperBound : 0
        let latest = index + 1 < count ? self[index + 1].range.lowerBound : duration
        let start = Swift.min(Swift.max(range.lowerBound + offset, earliest), latest - (range.upperBound - range.lowerBound))
        return updating(index) { $0.range = start..<start + range.upperBound - range.lowerBound }
    }

    /// The clips with `id` starting at `time` instead, stopping at the previous clip and keeping the
    /// minimum duration.
    func movingStart(of id: UUID, to time: Double) -> [Element] {
        guard let index = firstIndex(where: { $0.id == id }) else { return self }
        let range = self[index].range
        let earliest = index > 0 ? self[index - 1].range.upperBound : 0
        let start = Swift.max(Swift.min(time, range.upperBound - Element.minimumDuration), earliest)
        return updating(index) { $0.range = start..<range.upperBound }
    }

    /// The clips with `id` ending at `time` instead, stopping at the next clip or the lane's end and
    /// keeping the minimum duration.
    func movingEnd(of id: UUID, to time: Double, duration: Double) -> [Element] {
        guard let index = firstIndex(where: { $0.id == id }) else { return self }
        let range = self[index].range
        let latest = index + 1 < count ? self[index + 1].range.lowerBound : duration
        let end = Swift.min(Swift.max(time, range.lowerBound + Element.minimumDuration), latest)
        return updating(index) { $0.range = range.lowerBound..<end }
    }

    private func updating(_ index: Int, _ change: (inout Element) -> Void) -> [Element] {
        var clips = self
        change(&clips[index])
        clips[index].didEdit()
        return clips
    }
}
