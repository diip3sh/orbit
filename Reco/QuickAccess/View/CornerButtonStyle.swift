//
//  CornerButtonStyle.swift
//  Reco
//

import SwiftUI

/// A small dark circle with a white symbol, legible over any screenshot
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
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(.black.opacity(isLit ? 0.8 : 0.55), in: .circle)
            .contentShape(.circle)
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
            // The press shows on the frame it lands; only the release eases
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: isLit)
    }
}
