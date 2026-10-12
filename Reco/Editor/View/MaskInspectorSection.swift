//
//  MaskInspectorSection.swift
//  Reco
//

import SwiftUI

/// The selected mask's effect and rectangles, drawn on the frame where it starts.
struct MaskInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    /// The rectangle with handles on the pad.
    @State private var selectedRect = 0

    var body: some View {
        InspectorSection("Mask") {
            if let mask = Binding(unwrapping: $viewModel.selectedMask) {
                let rects = mask.rects
                InspectorField("Effect") {
                    SegmentedChoice(selection: mask.kind, options: MaskSegment.Kind.allCases.map { ($0, $0.title) })
                }
                if let videoSize = viewModel.videoSize {
                    RegionPad(
                        image: viewModel.croppedThumbnail(at: mask.wrappedValue.range.lowerBound),
                        videoSize: videoSize,
                        regions: rects,
                        selection: $selectedRect,
                        minimumSize: MaskSegment.minimumSize,
                        label: "Masked Areas"
                    )
                }
                HStack {
                    Button("Add Area", systemImage: "plus") {
                        rects.wrappedValue.append(MaskSegment.defaultRect)
                        selectedRect = rects.wrappedValue.count - 1
                    }
                    Button("Remove Area", systemImage: "minus") {
                        rects.wrappedValue.remove(at: min(selectedRect, rects.wrappedValue.count - 1))
                        selectedRect = max(selectedRect - 1, 0)
                    }
                    .disabled(rects.wrappedValue.count < 2)
                }
                .buttonStyle(.borderless)
            } else {
                Label("Press M to hide part of the frame from the playhead, or select a mask on the timeline.", systemImage: "eye.slash")
                    .foregroundStyle(EditorTheme.dim)
            }
            if let progress = viewModel.sensitiveInfoProgress {
                HStack {
                    ProgressView(value: progress)
                    Button("Cancel", action: viewModel.cancelFindingSensitiveInfo)
                        .buttonStyle(.borderless)
                }
            } else {
                Button {
                    viewModel.findSensitiveInfo()
                } label: {
                    Label("Find Sensitive Info", systemImage: "text.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.source == nil)
            }
        } footer: {
            if let found = viewModel.sensitiveInfoFound {
                Text(found == 0 ? "Found no emails, phone numbers, card numbers or API keys." : "Masked \(found) emails, phone numbers, card numbers or API keys.")
                // Never claims to have found everything: frames are read once a second
                Text("Check the recording before sharing it: text that shows for under a second, moves, or is very small can be missed.")
            }
        }
        .editorMotion(value: viewModel.selectedMask?.id)
        .editorMotion(value: viewModel.sensitiveInfoProgress == nil)
        .onChange(of: viewModel.selectedMask?.id) { selectedRect = 0 }
    }
}
