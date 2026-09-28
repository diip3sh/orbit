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
            .fill(.white.opacity(isHovered || isDragged ? 0.2 : 0.14))
            .overlay {
                shape.strokeBorder(isSelected ? EditorTheme.accent : EditorTheme.hairline, lineWidth: isSelected ? 2 : 1)
            }
            .overlay {
                Label {
                    Text("\(zoom.scale, format: .number.precision(.fractionLength(0...2)))×")
                } icon: {
                    Image(systemName: zoom.followsCursor ? "cursorarrow" : "scope")
                }
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, EditorTheme.smallSpacing)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(isDragged ? 0.5 : 0), radius: 6, y: 2)
            .pointerStyle(isDragged ? .grabActive : .grabIdle)
            .onHover { isHovered = $0 }
            .editorMotion(.snappy(duration: 0.18), value: isHovered)
    }
}
