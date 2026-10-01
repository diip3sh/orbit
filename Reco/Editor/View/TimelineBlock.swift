//
//  TimelineBlock.swift
//  Reco
//

import SwiftUI

/// A clip on a timeline lane: its span with a label when there's room. At rest a dark chip on a
/// hairline; selected, purple.
struct TimelineBlock<Label: View>: View {
    let isSelected: Bool
    let isDragged: Bool
    @ViewBuilder let label: Label

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
                label
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
            .editorMotion(EditorTheme.quickMotion, value: isHovered)
    }
}
