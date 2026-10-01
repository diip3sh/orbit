//
//  BackgroundSwatch.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A small picture of a canvas background, in the canvas's colors.
struct BackgroundSwatch: View {
    let background: CanvasStyle.Background
    let canvas: CanvasStyle

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5)

        Group {
            switch background {
            case .gradient:
                shape.fill(LinearGradient(
                    colors: [Color(cgColor: canvas.gradientStart.cgColor), Color(cgColor: canvas.gradientEnd.cgColor)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            case .color:
                shape.fill(Color(cgColor: canvas.color.cgColor))
            case .image:
                shape.fill(.primary.opacity(0.1))
                    .overlay {
                        Image(systemName: "photo")
                            .imageScale(.small)
                    }
            case .transparent:
                Checkerboard(square: 4)
                    .clipShape(shape)
            }
        }
        .overlay {
            shape.strokeBorder(EditorTheme.hairline)
        }
        .frame(width: 30)
    }
}
