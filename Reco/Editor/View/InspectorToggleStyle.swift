//
//  InspectorToggleStyle.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The title on the left and a small switch on the right edge: ink when on, with a knob that
/// slides across. The whole row switches it.
struct InspectorToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? AnyShapeStyle(EditorTheme.ink) : AnyShapeStyle(.primary.opacity(0.15)))
                    .frame(width: 32, height: 19)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(configuration.isOn ? EditorTheme.primaryInk : .white)
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                            .padding(2)
                    }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .editorMotion(value: configuration.isOn)
        .accessibilityRepresentation {
            Toggle(configuration)
        }
    }
}

extension ToggleStyle where Self == InspectorToggleStyle {
    static var inspector: Self { InspectorToggleStyle() }
}
