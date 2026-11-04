//
//  VideoOverlayLanes.swift
//  Reco
//

import Foundation

/// A project's overlays, in any order. ``TimelineClip``'s operations need one lane's, sorted, so these hand them that and
/// put the one clip they change back in its place: a move that changes nothing leaves the project equal.
nonisolated extension [VideoOverlay] {

    /// The lanes with an overlay on them, lowest first.
    var usedLanes: [Int] {
        Set(map(\.lane)).sorted()
    }

    /// The overlays on `lane`, sorted and apart.
    func onLane(_ lane: Int) -> [VideoOverlay] {
        filter { $0.lane == lane }.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Where an overlay starting at `time` goes: the lowest lane with room for the shortest, and the part of `length` that
    /// fits there. `nil` when no lane has room.
    func placement(at time: Double, length: Double, duration: Double) -> (lane: Int, range: Range<Double>)? {
        for lane in 0..<VideoOverlay.laneCount {
            if let range = onLane(lane).room(at: time, length: length, duration: duration) {
                return (lane, range)
            }
        }
        return nil
    }

    /// The overlays with `id` moved by `offset` seconds, stopping at its neighbours on its lane and the recording's ends.
    func movingOnLane(_ id: UUID, by offset: Double, duration: Double) -> [VideoOverlay] {
        changingOnLane(id) { $0.moving(id, by: offset, duration: duration) }
    }

    /// The overlays with `id` starting at `time` instead, stopping at the previous one on its lane.
    func movingStartOnLane(of id: UUID, to time: Double) -> [VideoOverlay] {
        changingOnLane(id) { $0.movingStart(of: id, to: time) }
    }

    /// The overlays with `id` ending at `time` instead, stopping at the next one on its lane or the recording's end.
    func movingEndOnLane(of id: UUID, to time: Double, duration: Double) -> [VideoOverlay] {
        changingOnLane(id) { $0.movingEnd(of: id, to: time, duration: duration) }
    }

    private func changingOnLane(_ id: UUID, _ change: ([VideoOverlay]) -> [VideoOverlay]) -> [VideoOverlay] {
        guard let overlay = first(where: { $0.id == id }),
              let changed = change(onLane(overlay.lane)).first(where: { $0.id == id }) else { return self }
        return replacing(changed)
    }
}
