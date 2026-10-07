//
//  MotionEditorView.swift
//  Reco
//

import SwiftUI

/// A motion bundle's window: the preview in the canvas's shape on the stage, the transport and the
/// scenes under it, the inspector and the agent chat beside it and Export in the toolbar.
struct MotionEditorView: View {
    let viewModel: MotionEditorViewModel
    let chat: AgentChatViewModel

    private static let cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let document = viewModel.document {
                let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                HStack(spacing: 0) {
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
                        MotionScenesLane(viewModel: viewModel)
                    }
                    .padding(EditorTheme.largeSpacing)
                    .background {
                        StageDotGrid()
                    }
                    MotionSidePanel(viewModel: viewModel, chat: chat)
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
        .frame(minWidth: 960, minHeight: 560)
        .editorWindowBackground()
        .task {
            await viewModel.load()
        }
    }
}
