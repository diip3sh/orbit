//
//  EditorSegmentedPicker.swift
//  Reco
//

import SwiftUI

/// A choice between a few words in a capsule. One thumb springs to the chosen word; it's chosen
/// the moment it's pressed, a drag across carries the thumb along, and the thumb shrinks a
/// little while held.
struct EditorSegmentedPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, name: LocalizedStringKey)]

    @Environment(\.isEnabled) private var isEnabled
    @State private var width: CGFloat = 0
    @State private var isPressed = false

    private static var inset: CGFloat { 2 }

    var body: some View {
        let segmentWidth = width / CGFloat(max(options.count, 1))
        let selected = options.firstIndex { $0.value == selection } ?? 0

        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Text(options[index].name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(index == selected ? EditorTheme.ink : EditorTheme.dim)
                    .frame(maxWidth: .infinity, minHeight: 26)
            }
        }
        .background(alignment: .leading) {
            Capsule()
                .fill(.primary.opacity(0.14))
                .overlay {
                    Capsule()
                        .strokeBorder(.primary.opacity(0.08))
                }
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                .frame(width: segmentWidth)
                .scaleEffect(isPressed ? 0.95 : 1)
                .offset(x: segmentWidth * CGFloat(selected))
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    isPressed = true
                    guard segmentWidth > 0 else { return }
                    let index = min(max(Int(drag.location.x / segmentWidth), 0), options.count - 1)
                    if options[index].value != selection {
                        selection = options[index].value
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .padding(Self.inset)
        .background(EditorTheme.tray, in: .capsule)
        .editorMotion(EditorTheme.slideMotion, value: selection)
        // The press shows on the frame it lands; only the release eases
        .editorMotion(isPressed ? nil : EditorTheme.quickMotion, value: isPressed)
        .accessibilityRepresentation {
            Picker("", selection: $selection) {
                ForEach(options.indices, id: \.self) { index in
                    Text(options[index].name).tag(options[index].value)
                }
            }
        }
    }
}
