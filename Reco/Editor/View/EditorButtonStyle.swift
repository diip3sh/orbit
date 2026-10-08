//
//  EditorButtonStyle.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import SwiftUI

/// Reco's two text buttons, solid with a 6 pt radius. The primary one is the accent fill with `onAccent` text, for the
/// one action a place leads to (Export, Render, Share, Save). The secondary one is the control fill with a hairline
/// edge and ink text, for everything else. Icons come from a `Label`; the `ButtonIcons` set in the asset catalog
/// draws them.
struct EditorButtonStyle: ButtonStyle {
    enum Role {
        case primary, secondary
    }

    var role = Role.secondary

    func makeBody(configuration: Configuration) -> some View {
        EditorButton(configuration: configuration, role: role)
    }
}

extension ButtonStyle where Self == EditorButtonStyle {
    static var editorPrimary: Self { EditorButtonStyle(role: .primary) }
    static var editorSecondary: Self { EditorButtonStyle(role: .secondary) }
}

private struct EditorButton: View {
    let configuration: ButtonStyleConfiguration
    let role: EditorButtonStyle.Role

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var shape: RoundedRectangle { .rect(cornerRadius: EditorTheme.smallRadius) }

    var body: some View {
        configuration.label
            .labelStyle(EditorButtonLabelStyle())
            .font(.theme(weight: .medium))
            .foregroundStyle(role == .primary ? EditorTheme.onAccent : EditorTheme.ink)
            .lineLimit(1)
            .padding(.horizontal, EditorTheme.mediumSpacing)
            .frame(minHeight: 30)
            .background { surface }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.4)
            // The press shows on the frame it lands; only the release eases
            .scaleEffect(isEnabled && configuration.isPressed ? 0.97 : 1)
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: configuration.isPressed)
            .onHover { isHovered = $0 }
            .editorMotion(EditorTheme.quickMotion, value: isHovered)
    }

    @ViewBuilder
    private var surface: some View {
        let isLit = isEnabled && (isHovered || configuration.isPressed)
        switch role {
        case .primary:
            shape.fill(isLit ? EditorTheme.primaryHover : EditorTheme.primary)
        case .secondary:
            shape.fill(EditorTheme.control)
            shape.fill(EditorTheme.ink.opacity(isLit ? 0.06 : 0))
            shape.strokeBorder(EditorTheme.hairline)
        }
    }
}

/// The icon before the title, in the title's colour.
private struct EditorButtonLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
            configuration.title
        }
    }
}
