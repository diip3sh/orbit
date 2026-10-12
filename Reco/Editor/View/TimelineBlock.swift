//
//  TimelineBlock.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A clip on a timeline lane: its span with a label when there's room. The tone tells what kind of
/// clip it is — a plain chip (masks), a dashed amber chip the app made (automatic zooms) or a solid
/// amber one the user placed (manual zooms); selected, ringed in ink.
struct TimelineBlock<Label: View>: View {

    /// What kind of clip the block holds.
    enum Tone {
        /// A plain chip in the raised fill (masks).
        case neutral
        /// A dashed amber chip, for a zoom the app made and the user hasn't touched.
        case automatic
        /// A solid amber chip, for a zoom the user placed or edited.
        case manual
    }

    let tone: Tone
    let isSelected: Bool
    let isDragged: Bool
    @ViewBuilder let label: Label

    init(tone: Tone = .neutral, isSelected: Bool, isDragged: Bool, @ViewBuilder label: () -> Label) {
        self.tone = tone
        self.isSelected = isSelected
        self.isDragged = isDragged
        self.label = label()
    }

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6)

        shape
            .fill(fill)
            .overlay {
                switch tone {
                case .neutral:
                    shape.strokeBorder(EditorTheme.hairline, lineWidth: 1)
                case .automatic:
                    shape.strokeBorder(EditorTheme.warning.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                case .manual:
                    EmptyView()
                }
            }
            .overlay {
                if isSelected {
                    shape.strokeBorder(EditorTheme.ink.opacity(0.6), lineWidth: 1.5)
                }
            }
            .overlay {
                label
                    .font(.theme(.caption2, weight: tone == .manual ? .semibold : .regular).monospacedDigit())
                    .foregroundStyle(text)
                    .lineLimit(1)
                    .padding(.horizontal, EditorTheme.smallSpacing)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(isDragged ? 0.5 : 0), radius: 6, y: 2)
            .pointerStyle(isDragged ? .grabActive : .grabIdle)
            .onHover { isHovered = $0 }
            .editorMotion(EditorTheme.quickMotion, value: isHovered)
    }

    private var fill: Color {
        switch tone {
        case .neutral:
            EditorTheme.raised
        case .automatic:
            EditorTheme.warning.opacity(isHovered || isDragged ? 0.24 : 0.16)
        case .manual:
            EditorTheme.warning.opacity(isHovered || isDragged ? 0.85 : 1)
        }
    }

    private var text: Color {
        switch tone {
        case .neutral:
            isSelected || isHovered ? EditorTheme.ink : EditorTheme.dim
        case .automatic:
            EditorTheme.warning
        case .manual:
            // Amber takes a dark label in both appearances
            .black.opacity(0.75)
        }
    }
}
