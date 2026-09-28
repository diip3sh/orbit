//
//  ExportFormatCard.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// An export format to pick: its name, what it's for, and whether it keeps HDR and transparency.
struct ExportFormatCard: View {
    let format: ExportFormat
    let isSelected: Bool

    /// Whether the recording is HDR, so whether keeping HDR is worth saying.
    let isHDR: Bool

    let select: () -> Void

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10)

        Button(action: select) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(format.rawValue)
                        .font(.headline)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AnyShapeStyle(EditorTheme.accent) : AnyShapeStyle(.tertiary))
                        .contentTransition(.symbolEffect(.replace))
                }
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    ForEach(badges, id: \.self) { badge in
                        Text(LocalizedStringKey(badge))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.white.opacity(0.1), in: .capsule)
                    }
                }
                .frame(height: 16)
            }
            .padding(12)
            .background(.white.opacity(isSelected ? 0.08 : isHovered ? 0.06 : 0.03), in: shape)
            .overlay {
                shape.strokeBorder(isSelected ? EditorTheme.accent : EditorTheme.hairline, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .editorMotion(.snappy(duration: 0.18), value: isHovered)
    }

    private var summary: LocalizedStringKey {
        switch format {
        case .hevc: "Small files, sharp"
        case .h264: "Plays everywhere"
        case .proRes422: "For editing apps"
        case .proRes4444: "For editing, with transparency"
        }
    }

    /// What the format keeps that others don't.
    private var badges: [String] {
        (isHDR && format.keepsHDR ? ["HDR"] : []) + (format.keepsTransparency ? ["Alpha"] : [])
    }
}
