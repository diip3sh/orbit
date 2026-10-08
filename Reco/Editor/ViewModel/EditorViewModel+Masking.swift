//
//  EditorViewModel+Masking.swift
//  Reco
//

import Foundation

// MARK: - Masking

extension EditorViewModel {

    /// The selected mask, for the inspector's controls. Each change is an edit; a drag is one undo step.
    var selectedMask: MaskSegment? {
        get {
            guard case .mask(let id) = selection else { return nil }
            return project.masks.first { $0.id == id }
        }
        set {
            guard let newValue else { return }
            edit("Mask", coalescing: true) { $0.masks = $0.masks.replacing(newValue) }
        }
    }

    /// Whether a mask can start at the playhead: it's outside the others, with room for the shortest.
    var canAddMask: Bool {
        newMaskAtPlayhead != nil
    }

    func selectMask(_ id: MaskSegment.ID) {
        selection = .mask(id)
    }

    /// Adds a blur mask in the middle of the frame at the playhead and selects it.
    func addMask() {
        guard let mask = newMaskAtPlayhead else { return }
        edit("Add Mask") { $0.masks = $0.masks.inserting(mask) }
        selection = .mask(mask.id)
    }

    /// Moves a mask by `offset` seconds, up to its neighbours and the recording's ends.
    func moveMask(_ id: MaskSegment.ID, by offset: Double) {
        guard let source else { return }
        edit("Move Mask") { $0.masks = $0.masks.moving(id, by: offset, duration: source.duration) }
    }

    func moveMaskStart(_ id: MaskSegment.ID, to time: Double) {
        edit("Resize Mask") { $0.masks = $0.masks.movingStart(of: id, to: time) }
    }

    func moveMaskEnd(_ id: MaskSegment.ID, to time: Double) {
        guard let source else { return }
        edit("Resize Mask") { $0.masks = $0.masks.movingEnd(of: id, to: time, duration: source.duration) }
    }

    private var newMaskAtPlayhead: MaskSegment? {
        guard let source else { return nil }
        return project.masks.newMask(at: timeMap.snapped(playheadSourceTime), duration: source.duration)
    }
}
