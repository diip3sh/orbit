//
//  InspectorToggleStyle.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The title on the left and ``EditorSwitch`` on the right edge. The whole row switches it.
struct InspectorToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
        }
        .buttonStyle(SwitchRowStyle(isOn: configuration.isOn))
        .accessibilityRepresentation {
            Toggle(configuration)
        }
    }
}

extension ToggleStyle where Self == InspectorToggleStyle {
    static var inspector: Self { InspectorToggleStyle() }
}

/// The row as a button, so the switch knows when it's pressed.
private struct SwitchRowStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            EditorSwitch(isOn: isOn, isPressed: configuration.isPressed)
        }
        .contentShape(.rect)
    }
}
