//
//  EditorView.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// An editor window's content: the preview, transport controls and timeline.
struct EditorView: View {
    let viewModel: EditorViewModel

    var body: some View {
        Group {
            if let source = viewModel.source {
                VStack(spacing: 0) {
                    PlayerLayerView(player: viewModel.playback.player)

                    TransportBar(playback: viewModel.playback, duration: viewModel.timeMap.outputDuration)

                    EditorTimelineView(viewModel: viewModel, videoSize: source.naturalSize)
                        .padding([.horizontal, .bottom])

                    if let error = viewModel.error {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .padding([.horizontal, .bottom])
                    }
                }
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Can't Open Recording",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                ProgressView()
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .task {
            await viewModel.load()
        }
    }
}
