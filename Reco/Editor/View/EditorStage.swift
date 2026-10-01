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

    private static let cornerRadius: CGFloat = 10

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius)

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
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .editorMotion(value: viewModel.error?.localizedDescription)
    }
}
