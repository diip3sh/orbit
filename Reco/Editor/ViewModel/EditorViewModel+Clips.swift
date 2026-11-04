//
//  EditorViewModel+Clips.swift
//  Reco
//

import Foundation

// MARK: - Clips

extension EditorViewModel {

    /// The kept parts between splits and cuts, in playing order. Everything on them is timed on the source, so it moves with them.
    var clips: [Range<Double>] {
        timeMap.clips(splitAt: project.splits)
    }

    /// Plays clip `index` at place `target` instead.
    func moveClip(_ index: Int, to target: Int) {
        guard clips.indices.contains(index), clips.indices.contains(target), index != target else { return }
        let sequence = timeMap.sequence(movingClip: index, to: target, splitAt: project.splits)
        edit("Move Clip") { $0.sequence = sequence }
    }

    /// Selects a clip and shows its first frame.
    func selectClip(_ clip: Range<Double>) {
        selection = segments.first { $0.contains(clip.lowerBound) }.map(EditorSelection.segment)
        seek(toSource: clip.lowerBound)
    }

    /// The place a clip dragged `distance` points from place `index` lands at, among `count` clips `slot` points apart.
    nonisolated static func clipTarget(from index: Int, distance: Double, slot: Double, count: Int) -> Int {
        guard slot > 0 else { return index }
        return min(max(index + Int((distance / slot).rounded()), 0), count - 1)
    }
}
