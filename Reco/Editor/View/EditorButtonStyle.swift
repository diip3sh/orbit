//
//  EditorButtonStyle.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import SwiftUI

/// Reco's two text buttons. The primary one, for the one action a place leads to (Export, Render, Share, Save), is a
/// capsule of Liquid Glass tinted with the accent fill and `onAccent` text on macOS 26, the solid accent fill before
/// that and with Reduce Transparency. The secondary one is the control fill with a 6 pt radius, a hairline edge and
/// ink text, for everything else. Icons come from a `Label`; the `ButtonIcons` set in the asset catalog
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
    @Environment(\.accessibilityReduceTransparency) private var reducesTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovered = false

    private var secondaryShape: RoundedRectangle { .rect(cornerRadius: EditorTheme.smallRadius) }

    private var shape: AnyShape {
        role == .primary ? AnyShape(.capsule) : AnyShape(secondaryShape)
    }

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
            if #available(macOS 26, *), !reducesTransparency {
                // Interactive glass answers the pointer and the press itself
                Color.clear
                    .glassEffect(.regular.tint(EditorTheme.primary).interactive(isEnabled), in: .capsule)
                    // Comes and goes with its panel, without glass's own grow on top
                    .glassEffectTransition(.identity)
                if contrast == .increased {
                    Capsule().strokeBorder(EditorTheme.hairline)
                }
            } else {
                Capsule().fill(isLit ? EditorTheme.primaryHover : EditorTheme.primary)
            }
        case .secondary:
            secondaryShape.fill(EditorTheme.control)
            secondaryShape.fill(EditorTheme.ink.opacity(isLit ? 0.06 : 0))
            secondaryShape.strokeBorder(EditorTheme.hairline)
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
