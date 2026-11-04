//
//  CaptionInspectorSection.swift
//  Reco
//

import SwiftUI

/// The Captions tab: generating them, how they look, and what they say.
@available(macOS 26, *)
struct CaptionInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: EditorTheme.largeSpacing) {
            CaptionGenerationSection(viewModel: viewModel)
            if !viewModel.captions.cues.isEmpty {
                CaptionStyleSection(viewModel: viewModel)
                CaptionCueList(viewModel: viewModel)
            }
        }
        .editorMotion(value: viewModel.captions.cues.isEmpty)
        .task {
            await viewModel.loadCaptionLanguages()
        }
    }
}
