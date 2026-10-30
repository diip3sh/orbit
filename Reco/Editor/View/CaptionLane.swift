//
//  CaptionLane.swift
//  Reco
//

import SwiftUI

/// The timeline's captions: clicking one selects it, dragging moves it, and its handles resize it.
struct CaptionLane: View {
    let viewModel: EditorViewModel

    /// The timeline's width, across which the recording is laid out.
    let width: CGFloat

    var body: some View {
        let selected = viewModel.selectedCaption?.id

        TimelineLane(
            clips: viewModel.project.captions.cues,
            viewport: viewModel.viewport,
            width: width,
            onSelect: viewModel.selectCaption,
            onMove: viewModel.moveCaption,
            onMoveStart: viewModel.moveCaptionStart,
            onMoveEnd: viewModel.moveCaptionEnd,
            selection: selected
        ) { cue, isDragged in
            TimelineBlock(isSelected: cue.id == selected, isDragged: isDragged) {
                Text(cue.text)
            }
        }
        .editorMotion(value: viewModel.project.captions.cues)
        .editorMotion(value: selected)
        .help("Captions: ⌫ deletes the selected one")
    }
}
