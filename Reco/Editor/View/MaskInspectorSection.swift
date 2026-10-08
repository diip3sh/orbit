//
//  MaskInspectorSection.swift
//  Reco
//

import SwiftUI

/// The selected mask's kind and rectangle, drawn on the frame where it starts.
struct MaskInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        InspectorSection("Mask") {
            if let mask = Binding(unwrapping: $viewModel.selectedMask) {
                InspectorField("Effect") {
                    SegmentedChoice(selection: mask.kind, options: MaskSegment.Kind.allCases.map { ($0, $0.title) })
                }
                if let videoSize = viewModel.videoSize {
                    RegionPad(
                        image: viewModel.croppedThumbnail(at: mask.wrappedValue.range.lowerBound),
                        videoSize: videoSize,
                        region: mask.rect,
                        minimumSize: MaskSegment.minimumSize,
                        label: "Masked Area"
                    )
                }
            } else {
                Label("Press M to hide part of the frame from the playhead.", systemImage: "eye.slash")
                    .foregroundStyle(EditorTheme.dim)
            }
        }
        .editorMotion(value: viewModel.selectedMask?.id)
    }
}
