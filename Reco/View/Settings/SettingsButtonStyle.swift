//
//  SettingsButtonStyle.swift
//  Reco
//

import SwiftUI

/// A Settings row's button: a raised capsule with a hairline edge and medium ink text, rose for a destructive role.
struct SettingsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SettingsButton(configuration: configuration)
    }
}

extension ButtonStyle where Self == SettingsButtonStyle {
    static var settings: Self { SettingsButtonStyle() }
}

private struct SettingsButton: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let isLit = isEnabled && (isHovered || configuration.isPressed)

        configuration.label
            .font(.theme(.callout, weight: .medium))
            .foregroundStyle(configuration.role == .destructive ? EditorTheme.danger : EditorTheme.ink)
            .lineLimit(1)
            .padding(.horizontal, EditorTheme.mediumSpacing)
            .frame(height: 28)
            .background(EditorTheme.ink.opacity(isLit ? 0.16 : 0.11), in: .capsule)
            .overlay(Capsule().strokeBorder(EditorTheme.ink.opacity(0.12)))
            .contentShape(.capsule)
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovered = $0 }
            .editorMotion(EditorTheme.quickMotion, value: isLit)
    }
}
