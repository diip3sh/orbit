//
//  CaptionCueList.swift
//  Reco
//

import SwiftUI

/// What the captions say, scrolling on its own under the controls, following the selection.
struct CaptionCueList: View {
    let viewModel: EditorViewModel

    /// Tall enough for about seven rows: a long recording has hundreds, and the style stays in reach.
    private static let maximumHeight: CGFloat = 340

    var body: some View {
        let selected = viewModel.selectedCaption?.id

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Captions")
            InspectorCard {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.captions.cues) { cue in
                                CaptionCueRow(viewModel: viewModel, cue: cue, isSelected: cue.id == selected)
                                    .id(cue.id)
                                InspectorHairline()
                            }
                        }
                    }
                    .scrollIndicators(.automatic)
                    .frame(maxHeight: Self.maximumHeight)
                    .onChange(of: selected) { _, selected in
                        if let selected {
                            proxy.scrollTo(selected)
                        }
                    }
                }
            }
        }
    }
}
