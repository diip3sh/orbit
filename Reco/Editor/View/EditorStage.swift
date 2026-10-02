//
//  EditorStage.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The preview in the canvas's shape, raised off a dark stage, with the transport under it.
struct EditorStage: View {
    let viewModel: EditorViewModel

    private static let cornerRadius: CGFloat = 8

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)

        VStack(spacing: EditorTheme.spacing) {
            PlayerLayerView(player: viewModel.playback.player, cornerRadius: Self.cornerRadius)
                .background {
                    if viewModel.canvas.background == .transparent {
                        Checkerboard(square: 10)
                            .clipShape(shape)
                    } else {
                        shape.fill(.black)
                    }
                }
                // A rim of light inside, and two shadows like a window on the desktop: a tight one
                // that seats it and a wide one that lifts it
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                .shadow(color: .black.opacity(0.28), radius: 32, y: 18)
                .overlay {
                    shape.strokeBorder(.white.opacity(0.1))
                }
                .overlay {
                    shape.stroke(.black.opacity(0.35), lineWidth: 0.5)
                }
                .aspectRatio(viewModel.exportSize(resolution: nil), contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            TransportBar(viewModel: viewModel)
        }
        .padding([.horizontal, .top], EditorTheme.largeSpacing)
        .padding(.bottom, EditorTheme.spacing)
        .background {
            StageDotGrid()
        }
        .overlay(alignment: .top) {
            if let error = viewModel.error {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .padding(.horizontal, EditorTheme.mediumSpacing)
                    .padding(.vertical, EditorTheme.smallSpacing)
                    .editorGlass(in: .capsule)
                    .padding(.top, EditorTheme.mediumSpacing)
                    .transition(.materialize(offset: -8))
            }
        }
        .editorMotion(value: viewModel.error?.localizedDescription)
    }
}
