//
//  EditorButtonStyle.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import SwiftUI

/// A text button: the primary one off-white with dark text, the ghost one a hairline outline whose
/// text brightens under the pointer.
struct EditorButtonStyle: ButtonStyle {
    var isPrimary = true

    func makeBody(configuration: Configuration) -> some View {
        EditorButton(configuration: configuration, isPrimary: isPrimary)
    }
}

extension ButtonStyle where Self == EditorButtonStyle {
    static var editorPrimary: Self { EditorButtonStyle() }
    static var editorGhost: Self { EditorButtonStyle(isPrimary: false) }
}

private struct EditorButton: View {
    let configuration: ButtonStyleConfiguration
    let isPrimary: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        let isLit = isEnabled && (isHovered || configuration.isPressed)

        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(isPrimary ? EditorTheme.primaryInk : isLit ? EditorTheme.ink : EditorTheme.dim)
            .padding(.horizontal, EditorTheme.mediumSpacing)
            .frame(minHeight: 28)
            .background {
                if isPrimary {
                    shape.fill(isLit ? EditorTheme.primaryHover : EditorTheme.primary)
                } else {
                    shape.fill(.primary.opacity(isEnabled && configuration.isPressed ? 0.06 : 0))
                    shape.strokeBorder(isLit ? EditorTheme.faint : EditorTheme.hairline)
                }
            }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
            // The press shows on the frame it lands; only the release eases
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: isLit)
    }
}
