//
//  MotionInspector.swift
//  Reco
//

import SwiftUI

/// The glass panel beside the stage: the selected scene's shot, slots, length and seam, its layers'
/// moves, and what the grammar's rules find. Enough to tune a document by hand (spec 0011, phase 3).
struct MotionInspector: View {
    let viewModel: MotionEditorViewModel

    private static let width: CGFloat = 320

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        ScrollView {
            VStack(spacing: 0) {
                MotionSceneSection(viewModel: viewModel)
                MotionLayerSection(viewModel: viewModel)
                MotionLintSection(findings: viewModel.findings)
            }
        }
        .scrollIndicators(.hidden)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .clipShape(shape)
        .editorGlass(in: shape)
        .padding([.trailing, .bottom], EditorTheme.mediumSpacing)
    }
}
