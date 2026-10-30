//
//  OverlayLane.swift
//  Reco
//

import SwiftUI

/// One overlay lane on the timeline: clicking an overlay selects it, dragging moves it, and its handles resize it.
struct OverlayLane: View {
    let viewModel: EditorViewModel
    let lane: Int

    /// The timeline's width, across which the recording is laid out.
    let width: CGFloat

    var body: some View {
        let selected = viewModel.selectedOverlay?.id
        let overlays = viewModel.project.overlays.onLane(lane)

        TimelineLane(
            clips: overlays,
            viewport: viewModel.viewport,
            width: width,
            onSelect: viewModel.selectOverlay,
            onMove: viewModel.moveOverlay,
            onMoveStart: viewModel.moveOverlayStart,
            onMoveEnd: viewModel.moveOverlayEnd,
            selection: selected
        ) { overlay, isDragged in
            TimelineBlock(isSelected: overlay.id == selected, isDragged: isDragged) {
                Label(overlay.title, systemImage: overlay.symbol)
            }
        }
        .editorMotion(value: overlays)
        .editorMotion(value: selected)
        .help("Overlays: T adds text at the playhead, ⌫ deletes the selected one")
    }
}
