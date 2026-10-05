//
//  EditorButtonStyle.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import SwiftUI

/// A text button: the primary one off-white with dark text, the accent one white on the system accent
/// colour (the floating capture panels' action, as the capture toolbar's), the ghost one a hairline
/// outline whose text brightens under the pointer.
struct EditorButtonStyle: ButtonStyle {
    enum Role {
        case primary, accent, ghost
    }

    var role = Role.primary

    func makeBody(configuration: Configuration) -> some View {
        EditorButton(configuration: configuration, role: role)
    }
}

extension ButtonStyle where Self == EditorButtonStyle {
    static var editorPrimary: Self { EditorButtonStyle() }
    static var editorAccent: Self { EditorButtonStyle(role: .accent) }
    static var editorGhost: Self { EditorButtonStyle(role: .ghost) }
}

private struct EditorButton: View {
    let configuration: ButtonStyleConfiguration
    let role: EditorButtonStyle.Role

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var isLit: Bool {
        isEnabled && (isHovered || configuration.isPressed)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8)

        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, EditorTheme.mediumSpacing)
            .frame(minHeight: 28)
            .background {
                switch role {
                case .primary:
                    shape.fill(isLit ? EditorTheme.primaryHover : EditorTheme.primary)
                case .accent:
                    shape.fill(EditorTheme.accent.opacity(configuration.isPressed ? 0.7 : isHovered ? 0.85 : 1))
                case .ghost:
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

    private var foreground: Color {
        switch role {
        case .primary: EditorTheme.primaryInk
        case .accent: .white
        case .ghost: isLit ? EditorTheme.ink : EditorTheme.dim
        }
    }
}
