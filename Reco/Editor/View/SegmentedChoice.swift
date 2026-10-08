//
//  SegmentedChoice.swift
//  Reco
//

import SwiftUI

/// A choice among a few short options: a track in the control fill with a raised fill that slides to the
/// chosen one. Replaces the system segmented control, whose accent fill would put lime on every choice in
/// the inspectors (the accent is kept for the playhead, the selection and the chosen tab).
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
                        .font(.theme(.callout))
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? EditorTheme.ink : EditorTheme.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .padding(.horizontal, EditorTheme.smallSpacing)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(EditorTheme.raised)
                                    .strokeBorder(EditorTheme.hairline)
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
        .background(EditorTheme.control, in: .rect(cornerRadius: 8))
        .editorMotion(EditorTheme.quickMotion, value: selection)
    }
}
