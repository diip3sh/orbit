//
//  CaptionStyleSection.swift
//  Reco
//

import SwiftUI

/// Whether captions show on the video, and how they look.
struct CaptionStyleSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let isEnabled = viewModel.captions.isEnabled

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Style")
            InspectorCard {
                VStack(spacing: 0) {
                    Toggle("Show Captions", isOn: $viewModel.captions.isEnabled)
                        .inspectorCardRow()
                    InspectorHairline()
                    Group {
                        InspectorSlider(
                            "Size", value: $viewModel.captions.style.size, in: CaptionStyle.sizes, defaultValue: CaptionStyle().size
                        ) { Text($0, format: .percent.precision(.fractionLength(1))) }
                        .inspectorCardRow()
                        InspectorHairline()
                        HStack {
                            Text("Position")
                            Spacer()
                            SegmentedChoice(
                                selection: $viewModel.captions.style.position,
                                options: CaptionStyle.Position.allCases.map { ($0, $0.title) },
                                trackFill: EditorTheme.panel
                            )
                            .fixedSize()
                        }
                        .inspectorCardRow()
                        InspectorHairline()
                        InspectorColorRow("Text Color") {
                            ColorPicker("Text Color", selection: $viewModel.captions.style.textColor.cgColor)
                        }
                        .inspectorCardRow()
                        InspectorHairline()
                        Toggle("Highlight Current Word", isOn: $viewModel.captions.style.highlightsWords)
                            .inspectorCardRow()
                        if viewModel.captions.style.highlightsWords {
                            InspectorHairline()
                            InspectorColorRow("Highlight Color") {
                                ColorPicker("Highlight Color", selection: $viewModel.captions.style.highlightColor.cgColor)
                            }
                            .inspectorCardRow()
                        }
                        InspectorHairline()
                        InspectorSlider(
                            "Background", value: $viewModel.captions.style.backgroundOpacity, in: 0...1, defaultValue: CaptionStyle().backgroundOpacity
                        ) { Text($0, format: .percent.precision(.fractionLength(0))) }
                        .inspectorCardRow()
                    }
                    // Text in ink doesn't dim by itself when disabled
                    .opacity(isEnabled ? 1 : 0.4)
                    .disabled(!isEnabled)
                }
            }
            InspectorNote("Subtitle files are written with or without captions on the video. Choose them when exporting.")
        }
        .editorMotion(value: viewModel.captions.style.highlightsWords)
    }
}
