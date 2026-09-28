//
//  TilePicker.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A row of tiles, each a picture over a name; the selection's highlight slides to the tile picked.
struct TilePicker<Value: Hashable, Picture: View>: View {
    @Binding var selection: Value
    let values: [Value]
    let name: (Value) -> LocalizedStringKey
    @ViewBuilder let picture: (Value) -> Picture

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 6) {
            ForEach(values, id: \.self) { value in
                let isSelected = value == selection
                Button {
                    selection = value
                } label: {
                    VStack(spacing: 6) {
                        picture(value)
                            .frame(height: 22)
                        Text(name(value))
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.1))
                                .strokeBorder(EditorTheme.accent, lineWidth: 1.5)
                                .matchedGeometryEffect(id: "highlight", in: highlight)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.04))
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
