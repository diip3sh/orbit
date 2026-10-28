//
//  SettingsToggleStyle.swift
//  Reco
//

import SwiftUI

/// A Settings row with an accent ``EditorSwitch`` on the right edge. The whole row switches it.
struct SettingsToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
        }
        .buttonStyle(SettingsSwitchRowStyle(isOn: configuration.isOn))
        .accessibilityRepresentation {
            Toggle(configuration)
        }
    }
}

extension ToggleStyle where Self == SettingsToggleStyle {
    static var settings: Self { SettingsToggleStyle() }
}

/// The row as a button, so the switch knows when it's pressed.
private struct SettingsSwitchRowStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        SettingsRow {
            configuration.label
        } trailing: {
            EditorSwitch(isOn: isOn, isPressed: configuration.isPressed, tint: EditorTheme.accentFill)
        }
        .contentShape(.rect)
    }
}
