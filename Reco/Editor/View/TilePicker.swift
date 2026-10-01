//
//  TilePicker.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A row of tiles, each a picture over a name; the selection's lighter fill slides to the tile picked.
struct TilePicker<Value: Hashable, Picture: View>: View {
    @Binding var selection: Value
    let values: [Value]
    let name: (Value) -> LocalizedStringKey
    @ViewBuilder let picture: (Value) -> Picture

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: EditorTheme.tightSpacing) {
            ForEach(values, id: \.self) { value in
                let isSelected = value == selection
                Button {
                    selection = value
                } label: {
                    VStack(spacing: EditorTheme.tightSpacing) {
                        picture(value)
                            .frame(height: 22)
                        Text(name(value))
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(isSelected ? EditorTheme.ink : EditorTheme.dim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EditorTheme.smallSpacing)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.primary.opacity(0.1))
                                .matchedGeometryEffect(id: "highlight", in: highlight)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(EditorTheme.softHairline)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .editorMotion(value: selection)
    }
}
