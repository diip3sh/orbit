//
//  EditorSegmentedPicker.swift
//  Reco
//

import SwiftUI

/// A choice between a few words in a capsule, whose highlight slides to the chosen one.
struct EditorSegmentedPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, name: LocalizedStringKey)]

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection

                Button {
                    selection = option.value
                } label: {
                    Text(option.name)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(isSelected ? EditorTheme.ink : EditorTheme.dim)
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(.primary.opacity(0.12))
                                    .matchedGeometryEffect(id: "highlight", in: highlight)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(EditorTheme.tray, in: .capsule)
        .editorMotion(value: selection)
    }
}
