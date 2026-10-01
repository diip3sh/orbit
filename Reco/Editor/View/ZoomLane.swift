//
//  ZoomLane.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The timeline's zooms: clicking one selects it, dragging moves it, and its handles resize it.
struct ZoomLane: View {
    let viewModel: EditorViewModel

    /// The timeline's width, across which the recording is laid out.
    let width: CGFloat

    var body: some View {
        let selected = viewModel.selectedZoom?.id

        TimelineLane(
            clips: viewModel.project.zooms,
            duration: viewModel.timeMap.sourceDuration,
            width: width,
            onSelect: { viewModel.selectZoom($0) },
            onMove: { viewModel.moveZoom($0, by: $1) },
            onMoveStart: { viewModel.moveZoomStart($0, to: $1) },
            onMoveEnd: { viewModel.moveZoomEnd($0, to: $1) },
            block: { zoom, isDragged in
                ZoomBlock(zoom: zoom, isSelected: zoom.id == selected, isDragged: isDragged)
            }
        )
        .editorMotion(value: viewModel.project.zooms)
        .editorMotion(value: selected)
        .help("Zooms: Z adds one at the playhead, ⌫ deletes the selected one")
    }
}
