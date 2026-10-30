//
//  ArrowOverlayCard.swift
//  Reco
//

import SwiftUI

/// An arrow's look. Its ends are dragged on the stage.
struct ArrowOverlayCard: View {
    @Binding var style: ArrowOverlayStyle

    var body: some View {
        InspectorCard {
            VStack(spacing: 0) {
                InspectorColorRow("Color") {
                    ColorPicker("Color", selection: $style.color.cgColor)
                }
                .inspectorCardRow()
                InspectorHairline()
                InspectorSlider("Width", value: $style.strokeWidth, in: ArrowOverlayStyle.strokeWidths, defaultValue: ArrowOverlayStyle().strokeWidth) {
                    Text($0, format: .percent.precision(.fractionLength(1)))
                }
                .inspectorCardRow()
            }
        }
    }
}
