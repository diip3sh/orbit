//
//  ZoomBlock.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A zoom on the timeline's zoom lane: its span, with its scale when there's room. At rest a dark
/// chip on a hairline; selected, purple.
struct ZoomBlock: View {
    let zoom: ZoomSegment
    let isSelected: Bool
    let isDragged: Bool

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6)

        shape
            .fill(isSelected ? EditorTheme.accent.opacity(0.2) : EditorTheme.panel)
            .overlay {
                shape.strokeBorder(
                    isSelected ? EditorTheme.accent : isHovered || isDragged ? EditorTheme.faint : EditorTheme.hairline,
                    lineWidth: isSelected ? 1.5 : 1
                )
            }
            .overlay {
                Label {
                    Text("\(zoom.scale, format: .number.precision(.fractionLength(0...2)))×")
                } icon: {
                    Image(systemName: zoom.followsCursor ? "cursorarrow" : "scope")
                }
                .font(.caption2)
                .monospaced()
                .foregroundStyle(isSelected || isHovered ? EditorTheme.ink : EditorTheme.dim)
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
