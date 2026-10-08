//
//  MaskLane.swift
//  Reco
//

import SwiftUI

/// The timeline's masks: clicking one selects it, dragging moves it, and its handles resize it.
struct MaskLane: View {
    let viewModel: EditorViewModel

    /// The timeline's width, across which the recording is laid out.
    let width: CGFloat

    var body: some View {
        let selected = viewModel.selectedMask?.id

        TimelineLane(
            clips: viewModel.project.masks,
            duration: viewModel.timeMap.sourceDuration,
            width: width,
            onSelect: viewModel.selectMask,
            onMove: viewModel.moveMask,
            onMoveStart: viewModel.moveMaskStart,
            onMoveEnd: viewModel.moveMaskEnd,
            selection: selected
        ) { mask, isDragged in
            MaskBlock(mask: mask, isSelected: mask.id == selected, isDragged: isDragged)
        }
        .editorMotion(value: viewModel.project.masks)
        .editorMotion(value: selected)
        .help("Masks: M adds one at the playhead, ⌫ deletes the selected one")
    }
}

/// A mask on the timeline's mask lane, with its effect when there's room.
struct MaskBlock: View {
    let mask: MaskSegment
    let isSelected: Bool
    let isDragged: Bool

    var body: some View {
        TimelineBlock(isSelected: isSelected, isDragged: isDragged) {
            Label(mask.kind.title, systemImage: mask.kind.symbol)
        }
    }
}
