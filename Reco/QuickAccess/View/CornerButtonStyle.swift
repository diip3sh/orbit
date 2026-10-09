//
//  CornerButtonStyle.swift
//  Reco
//

import SwiftUI

/// A small circle in the control colour with an ink symbol and a hairline edge, legible over any screenshot
struct CornerButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        CornerButton(configuration: configuration)
    }
}

private struct CornerButton: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let isLit = isEnabled && (isHovered || configuration.isPressed)

        configuration.label
            .font(.theme(.caption, weight: .semibold))
            .foregroundStyle(EditorTheme.ink)
            .frame(width: 24, height: 24)
            .background(EditorTheme.control.mix(with: EditorTheme.ink, by: isLit ? 0.1 : 0), in: .circle)
            .overlay(Circle().strokeBorder(EditorTheme.hairline))
            .contentShape(.circle)
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
            // The press shows on the frame it lands; only the release eases
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: isLit)
    }
}
