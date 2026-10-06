//
//  MotionEditorView.swift
//  Reco
//

import SwiftUI

/// A motion bundle's window: the preview in the canvas's shape on the stage, the transport under it
/// and Export in the toolbar. Editing comes in spec 0011's phase 6.
struct MotionEditorView: View {
    let viewModel: MotionEditorViewModel

    private static let cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let document = viewModel.document {
                let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                VStack(spacing: EditorTheme.spacing) {
                    PlayerLayerView(player: viewModel.playback.player, cornerRadius: Self.cornerRadius)
                        .background(.black, in: shape)
                        .shadow(color: .black.opacity(0.28), radius: 32, y: 18)
                        .overlay {
                            shape.strokeBorder(.white.opacity(0.1))
                        }
                        .aspectRatio(document.canvas.size, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    MotionTransportBar(viewModel: viewModel)
                }
                .padding(EditorTheme.largeSpacing)
                .background {
                    StageDotGrid()
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        MotionExportMenu(viewModel: viewModel)
                    }
                }
            } else if let error = viewModel.error {
                ContentUnavailableView("Can't Open Motion Video", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(minWidth: 640, minHeight: 420)
        .editorWindowBackground()
        .task {
            await viewModel.load()
        }
    }
}
