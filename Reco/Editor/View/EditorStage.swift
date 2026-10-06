//
//  EditorStage.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The preview in the canvas's shape, raised off the stage.
struct EditorStage: View {
    let viewModel: EditorViewModel

    private static let cornerRadius: CGFloat = 10

    var body: some View {
        // Continuous, like the player layer's corners: a circular one left the black backing showing at each corner
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)

        PlayerLayerView(player: viewModel.playback.player, cornerRadius: Self.cornerRadius)
            // The player layer's own corner radius doesn't clip its video: the frame showed square corners past the ring
            .clipShape(shape)
            .background {
                if viewModel.canvas.background == .transparent {
                    Checkerboard(square: 10)
                        .clipShape(shape)
                } else {
                    shape.fill(.black)
                }
            }
            // A rim of light inside, a dark ring outside and a deep shadow, like a window on the desktop
            .shadow(color: .black.opacity(0.7), radius: 24, y: 24)
            .overlay {
                shape.strokeBorder(.white.opacity(0.1))
            }
            .overlay {
                shape.stroke(.black.opacity(0.9), lineWidth: 1)
            }
            .aspectRatio(viewModel.exportSize(resolution: nil), contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(EditorTheme.largeSpacing)
            .background {
                StageDotGrid()
            }
            .overlay(alignment: .top) {
                if let error = viewModel.error {
                    StatusBanner(message: error.localizedDescription) { viewModel.error = nil }
                        .padding(.top, EditorTheme.mediumSpacing)
                }
            }
            .editorMotion(value: viewModel.error?.localizedDescription)
    }
}
