//
//  CursorStylePicture.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import SwiftUI

/// A cursor style's tile picture: the arrow it draws, or the dot.
struct CursorStylePicture: View {
    let appearance: CursorStyle.Appearance

    var body: some View {
        switch appearance {
        case .recorded:
            Image(systemName: "cursorarrow")
                .foregroundStyle(.black)
                .shadow(color: .white, radius: 0.75)
        case .white:
            Image(systemName: "cursorarrow")
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 0.75)
        case .dot:
            Circle()
                .fill(.gray.opacity(0.9))
                .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                .frame(width: 14, height: 14)
        }
    }
}
