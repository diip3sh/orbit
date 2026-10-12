//
//  GlyphSegmentedPicker.swift
//  Reco
//

import SwiftUI

/// A choice among a few options, each a small picture beside its name, in a track that sits a step under
/// the card around it. The chosen option's fill slides to it, as in `SegmentedChoice`; where that one is
/// words only and takes the column's width, this one is for options a picture names better (canvas shapes,
/// background kinds).
struct GlyphSegmentedPicker<Value: Hashable, Glyph: View>: View {
    @Binding var selection: Value
    let options: [(value: Value, name: LocalizedStringKey)]
    @ViewBuilder let glyph: (Value) -> Glyph

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    HStack(spacing: 5) {
                        glyph(option.value)
                        Text(option.name)
                            .font(.theme(.caption2, weight: isSelected ? .medium : nil))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? EditorTheme.ink : EditorTheme.dim)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.primary.opacity(0.14))
                                .matchedGeometryEffect(id: "highlight", in: highlight)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .frame(height: 38)
        .background(EditorTheme.panel, in: .rect(cornerRadius: 9, style: .continuous))
        .editorMotion(EditorTheme.quickMotion, value: selection)
    }
}
