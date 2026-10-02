//
//  InspectorSlider.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A slider under its title and current value.
struct InspectorSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>

    /// The value as shown, e.g. "8%" or "2×".
    let label: (Double) -> Text

    init(_ title: LocalizedStringKey, value: Binding<Double>, in range: ClosedRange<Double>, label: @escaping (Double) -> Text) {
        self.title = title
        _value = value
        self.range = range
        self.label = label
    }

    var body: some View {
        VStack(spacing: EditorTheme.tightSpacing) {
            HStack {
                Text(title)
                Spacer()
                label(value)
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(EditorTheme.dim)
            }
            EditorSlider(value: $value, range: range)
        }
    }
}
