//
//  TextOverlayCard.swift
//  Reco
//

import SwiftUI

/// A text overlay's words and look. Return ends the field, so T and ⌫ are the timeline's again; ⌥Return starts a line.
struct TextOverlayCard: View {
    @Binding var style: TextOverlayStyle

    @FocusState private var isEditing: Bool

    var body: some View {
        InspectorCard {
            VStack(spacing: 0) {
                TextField("Text", text: $style.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .labelsHidden()
                    .lineLimit(1...6)
                    .focused($isEditing)
                    .onSubmit { isEditing = false }
                    .inspectorCardRow()
                InspectorHairline()
                InspectorSlider("Size", value: $style.size, in: TextOverlayStyle.sizes, defaultValue: TextOverlayStyle().size) {
                    Text($0, format: .percent.precision(.fractionLength(1)))
                }
                .inspectorCardRow()
                InspectorHairline()
                HStack {
                    Text("Alignment")
                    Spacer()
                    SegmentedChoice(
                        selection: $style.alignment,
                        options: TextOverlayStyle.Alignment.allCases.map { ($0, $0.title) },
                        trackFill: EditorTheme.panel
                    )
                    .fixedSize()
                }
                .inspectorCardRow()
                InspectorHairline()
                Toggle("Bold", isOn: $style.isBold)
                    .inspectorCardRow()
                InspectorHairline()
                InspectorColorRow("Text Color") {
                    ColorPicker("Text Color", selection: $style.color.cgColor)
                }
                .inspectorCardRow()
                InspectorHairline()
                InspectorColorRow("Background Color") {
                    ColorPicker("Background Color", selection: $style.backgroundColor.cgColor)
                }
                .inspectorCardRow()
                InspectorHairline()
                InspectorSlider("Background", value: $style.backgroundOpacity, in: 0...1, defaultValue: TextOverlayStyle().backgroundOpacity) {
                    Text($0, format: .percent.precision(.fractionLength(0)))
                }
                .inspectorCardRow()
            }
        }
    }
}
