//
//  EditorButtonStyle.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import SwiftUI

/// Reco's two text buttons, as Liquid Glass capsules. The primary one is glass tinted with the accent colour and
/// white text, for the one action a place leads to (Export, Render, Share, Save). The secondary one is clear glass
/// with accent text and its icon white on an accent disc, for everything else. Icons come from a `Label`; the
/// `ButtonIcons` set in the asset catalog draws them.
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

    var body: some View {
        configuration.label
            .labelStyle(EditorButtonLabelStyle(role: role))
            .font(.body.weight(.semibold))
            .foregroundStyle(role == .primary ? Color.white : EditorTheme.accent)
            .lineLimit(1)
            .padding(.leading, EditorTheme.mediumSpacing)
            .padding(.trailing, EditorTheme.mediumSpacing + 2)
            .frame(minHeight: 30)
            .background { surface }
            .contentShape(.capsule)
            .overlay {
                // Increase Contrast: a defined edge on every surface
                if contrast == .increased {
                    Capsule().strokeBorder(EditorTheme.dim)
                }
            }
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
        if reducesTransparency {
            switch role {
            case .primary:
                Capsule().fill(EditorTheme.accent.opacity(isLit ? 0.85 : 1))
            case .secondary:
                Capsule().fill(EditorTheme.stage)
                Capsule().fill(.primary.opacity(isLit ? 0.06 : 0))
                Capsule().strokeBorder(EditorTheme.hairline)
            }
        } else if #available(macOS 26, *) {
            // Interactive glass answers the pointer itself, as system glass buttons do
            switch role {
            case .primary:
                Color.clear.glassEffect(.regular.tint(EditorTheme.accent).interactive(isEnabled), in: .capsule)
            case .secondary:
                Color.clear.glassEffect(.regular.interactive(isEnabled), in: .capsule)
            }
        } else {
            switch role {
            case .primary:
                Capsule().fill(EditorTheme.accent.opacity(isLit ? 0.85 : 1))
            case .secondary:
                Capsule().fill(.regularMaterial)
                Capsule().fill(.primary.opacity(isLit ? 0.06 : 0))
                Capsule().strokeBorder(EditorTheme.hairline)
            }
        }
    }
}

/// The icon before the title: plain on the primary button, white on an accent disc on the secondary one.
private struct EditorButtonLabelStyle: LabelStyle {
    let role: EditorButtonStyle.Role

    /// The disc's size, and how much the 14 pt icon shrinks to sit inside it with room around.
    private static let disc: CGFloat = 20
    private static let iconScale: CGFloat = 0.78

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: role == .primary ? 6 : EditorTheme.smallSpacing) {
            switch role {
            case .primary:
                configuration.icon
            case .secondary:
                configuration.icon
                    .scaleEffect(Self.iconScale)
                    .foregroundStyle(.white)
                    .frame(width: Self.disc, height: Self.disc)
                    .background(EditorTheme.accent, in: .circle)
                    // Sits closer to the capsule's edge, as the title does to the other one
                    .padding(.leading, -EditorTheme.tightSpacing)
            }
            configuration.title
        }
    }
}
