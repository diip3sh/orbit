//
//  MotionInspector.swift
//  Reco
//

import SwiftUI

/// The side panel's Style half: the selected scene's shot, slots, length, seam and field, its layers'
/// moves, and what the grammar's rules find. Enough to tune a document by hand (spec 0011, phase 3).
struct MotionInspector: View {
    let viewModel: MotionEditorViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MotionSceneSection(viewModel: viewModel)
                MotionLayerSection(viewModel: viewModel)
                MotionLintSection(findings: viewModel.findings)
            }
        }
        .scrollIndicators(.hidden)
    }
}
