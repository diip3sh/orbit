//
//  SwatchGrid.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import SwiftUI

/// Small pictures in rows of five, the chosen one ringed in the accent color.
struct SwatchGrid<Value: Identifiable, Swatch: View>: View {
    let values: [Value]
    let selection: Value.ID?
    let name: (Value) -> String
    let pick: (Value) -> Void
    @ViewBuilder let swatch: (Value) -> Swatch

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: EditorTheme.tightSpacing), count: 5), spacing: EditorTheme.tightSpacing) {
            ForEach(values) { value in
                let isSelected = value.id == selection
                Button {
                    pick(value)
                } label: {
                    Color.clear
                        .aspectRatio(16 / 10, contentMode: .fit)
                        .overlay {
                            swatch(value)
                                .scaledToFill()
                        }
                        .clipShape(shape)
                        .overlay {
                            shape.strokeBorder(isSelected ? EditorTheme.accent : EditorTheme.hairline, lineWidth: isSelected ? 2 : 1)
                        }
                        .contentShape(shape)
                }
                .buttonStyle(.plain)
                .help(name(value))
                .accessibilityLabel(name(value))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .editorMotion(value: selection)
    }
}
