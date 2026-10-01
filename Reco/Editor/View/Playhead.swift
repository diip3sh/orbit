//
//  Playhead.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A line across the timeline with a knob in the ruler, pointing down at the frame shown.
struct Playhead: View {

    /// The knob's height, the ruler's.
    let knobHeight: CGFloat

    static let knobWidth: CGFloat = 11

    var body: some View {
        VStack(spacing: 0) {
            Knob()
                .fill(EditorTheme.accent)
                .frame(width: Self.knobWidth, height: knobHeight)
            Rectangle()
                .fill(EditorTheme.accent)
                .frame(width: 1.5)
        }
        .shadow(color: .black.opacity(0.5), radius: 2)
    }

    /// Rounded at the top and pointed at the bottom.
    private nonisolated struct Knob: Shape {
        func path(in rect: CGRect) -> Path {
            let point = rect.height * 0.35
            var path = Path()
            path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - point), cornerSize: CGSize(width: 2.5, height: 2.5))
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - point - 1))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - point - 1))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}
