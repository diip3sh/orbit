//
//  ZoomBlock.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A zoom on the timeline's zoom lane: its span, with its scale when there's room.
struct ZoomBlock: View {
    let zoom: ZoomSegment
    let isSelected: Bool
    let isDragged: Bool

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6)

        shape
            .fill(LinearGradient(
                colors: [EditorTheme.zoom.opacity(0.95), EditorTheme.zoom.opacity(0.7)], startPoint: .top, endPoint: .bottom
            ))
            .brightness(isHovered || isDragged ? 0.08 : 0)
            .overlay {
                shape.strokeBorder(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.18)), lineWidth: isSelected ? 2 : 1)
            }
            .overlay {
                Label {
                    Text("\(zoom.scale, format: .number.precision(.fractionLength(0...2)))×")
                } icon: {
                    Image(systemName: zoom.followsCursor ? "cursorarrow" : "scope")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(isDragged ? 0.5 : 0), radius: 6, y: 2)
            .pointerStyle(isDragged ? .grabActive : .grabIdle)
            .onHover { isHovered = $0 }
            .editorMotion(.snappy(duration: 0.18), value: isHovered)
    }
}
