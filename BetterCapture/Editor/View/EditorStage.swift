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

        VStack(spacing: 20) {
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
        .padding([.horizontal, .top], 28)
        .padding(.bottom, 16)
        .background {
            // A soft light behind the preview, so the stage and the glass on it have depth
            RadialGradient(colors: [.white.opacity(0.05), .clear], center: .center, startRadius: 0, endRadius: 700)
        }
        .overlay(alignment: .top) {
            if let error = viewModel.error {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .editorGlass(in: .capsule)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .editorMotion(value: viewModel.error?.localizedDescription)
    }
}
