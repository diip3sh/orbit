//
//  EditorStage.swift
//  BetterCapture
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
                .shadow(color: .black.opacity(0.6), radius: 28, y: 14)
                .overlay {
                    shape.strokeBorder(EditorTheme.hairline)
                }
                .aspectRatio(viewModel.exportSize(resolution: nil), contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            TransportBar(viewModel: viewModel)
        }
        .padding([.horizontal, .top], EditorTheme.largeSpacing)
        .padding(.bottom, EditorTheme.spacing)
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
