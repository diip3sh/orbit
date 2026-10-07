//
//  SegmentedChoice.swift
//  Reco
//

import SwiftUI

/// A choice among a few short options, in the studio windows' look: a neutral track with a light fill
/// that slides to the chosen one. Replaces the system segmented control, whose accent fill was the
/// only blue in the inspectors (the accent is kept for the playhead and the selection).
struct SegmentedChoice<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    /// Whether an option can be chosen; one that can't is dimmed.
    var isEnabled: (Value) -> Bool = { _ in true }

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(.callout)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? EditorTheme.ink : EditorTheme.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .padding(.horizontal, EditorTheme.smallSpacing)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(EditorTheme.stage)
                                    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                                    .matchedGeometryEffect(id: "highlight", in: highlight)
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled(option.value))
                .opacity(isEnabled(option.value) ? 1 : 0.4)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(EditorTheme.softHairline, in: .rect(cornerRadius: 8))
        .editorMotion(EditorTheme.quickMotion, value: selection)
    }
}
