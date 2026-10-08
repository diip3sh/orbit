//
//  InspectorSlider.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A tick-mark slider under its title and current value.
struct InspectorSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>

    /// The value Reset brings back, shown once the value is another.
    let defaultValue: Double?

    /// The value as shown, e.g. "8%" or "2×".
    let label: (Double) -> Text

    init(
        _ title: LocalizedStringKey, value: Binding<Double>, in range: ClosedRange<Double>, defaultValue: Double? = nil,
        label: @escaping (Double) -> Text
    ) {
        self.title = title
        _value = value
        self.range = range
        self.defaultValue = defaultValue
        self.label = label
    }

    var body: some View {
        VStack(spacing: EditorTheme.tightSpacing) {
            HStack {
                Text(title)
                Spacer()
                if let defaultValue, value != defaultValue {
                    Button("Reset") {
                        value = defaultValue
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .transition(.opacity)
                }
                label(value)
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(EditorTheme.dim)
            }
            TickSlider(title: title, value: $value, range: range, valueLabel: label(value))
        }
        .editorMotion(EditorTheme.quickMotion, value: value != defaultValue)
    }
}
