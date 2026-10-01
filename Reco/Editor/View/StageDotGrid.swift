//
//  StageDotGrid.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import SwiftUI

/// A faint dot grid behind the preview that fades out before the stage's edges.
struct StageDotGrid: View {
    private static let spacing: CGFloat = 23
    private static let dotSize: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            var dots = Path()
            for row in 0...Int(size.height / Self.spacing) {
                for column in 0...Int(size.width / Self.spacing) {
                    let center = CGPoint(x: (Double(column) + 0.5) * Self.spacing, y: (Double(row) + 0.5) * Self.spacing)
                    dots.addEllipse(in: CGRect(x: center.x - Self.dotSize / 2, y: center.y - Self.dotSize / 2, width: Self.dotSize, height: Self.dotSize))
                }
            }
            context.fill(dots, with: .color(EditorTheme.faint.opacity(0.5)))
        }
        .mask {
            EllipticalGradient(stops: [.init(color: .black, location: 0.3), .init(color: .clear, location: 1)], endRadiusFraction: 0.72)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
