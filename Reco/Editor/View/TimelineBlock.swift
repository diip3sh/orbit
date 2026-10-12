//
//  TimelineBlock.swift
//  Reco
//

import SwiftUI

/// A clip on a timeline lane: its span with a label when there's room. A chip in the control fill on a
/// hairline, so it stands off the lane; selected, ringed in the accent.
struct TimelineBlock<Label: View>: View {
    let isSelected: Bool
    let isDragged: Bool
    @ViewBuilder let label: Label

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6)

        shape
            .fill(EditorTheme.control)
            .overlay {
                shape.strokeBorder(
                    isSelected ? EditorTheme.accent : isHovered || isDragged ? EditorTheme.faint : EditorTheme.hairline,
                    lineWidth: isSelected ? 1.5 : 1
                )
            }
            .overlay {
                label
                    .font(.theme(.caption2).monospacedDigit())
                    .foregroundStyle(isSelected || isHovered ? EditorTheme.ink : EditorTheme.dim)
                    .lineLimit(1)
                    .padding(.horizontal, EditorTheme.smallSpacing)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(isDragged ? 0.5 : 0), radius: 6, y: 2)
            .pointerStyle(isDragged ? .grabActive : .grabIdle)
            .onHover { isHovered = $0 }
            .editorMotion(EditorTheme.quickMotion, value: isHovered)
    }
}
