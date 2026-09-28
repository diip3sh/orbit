//
//  ZoomLane.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The timeline's zooms: clicking one selects it, dragging moves it, and its handles resize it.
struct ZoomLane: View {
    let viewModel: EditorViewModel

    /// The timeline's width, across which the recording is laid out.
    let width: CGFloat

    /// The zoom being dragged and how far, in points.
    @State private var drag: (id: ZoomSegment.ID, offset: CGFloat)?

    static let height: CGFloat = 24

    /// How far the pointer may move for a press to still count as a click.
    private static let clickTolerance: CGFloat = 3

    var body: some View {
        let duration = viewModel.timeMap.sourceDuration
        let selected = viewModel.selectedZoom?.id

        ZStack(alignment: .leading) {
            if duration > 0 {
                ForEach(viewModel.project.zooms) { zoom in
                    let start = zoom.range.lowerBound / duration * width
                    let end = zoom.range.upperBound / duration * width
                    let dragged = drag.flatMap { $0.id == zoom.id ? $0.offset : nil } ?? 0

                    ZoomBlock(zoom: zoom, isSelected: zoom.id == selected, isDragged: drag?.id == zoom.id)
                        .frame(width: end - start)
                        .offset(x: start + dragged)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag = (zoom.id, $0.translation.width) }
                                .onEnded { value in
                                    drag = nil
                                    if abs(value.translation.width) < Self.clickTolerance {
                                        viewModel.selectZoom(zoom.id)
                                    } else {
                                        viewModel.moveZoom(zoom.id, by: value.translation.width / width * duration)
                                    }
                                }
                        )

                    TrimHandle(edge: .leading, position: start) { position in
                        viewModel.moveZoomStart(zoom.id, to: position / width * duration)
                    }
                    TrimHandle(edge: .trailing, position: end) { position in
                        viewModel.moveZoomEnd(zoom.id, to: position / width * duration)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .leading)
        .background(.white.opacity(0.03), in: .rect(cornerRadius: 6))
        .editorMotion(value: viewModel.project.zooms)
        .editorMotion(value: selected)
        .help("Zooms: Z adds one at the playhead, ⌫ deletes the selected one")
    }
}
