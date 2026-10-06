//
//  AgentChipButtonStyle.swift
//  Reco
//

import SwiftUI

/// The agent chat's small buttons: suggestion chips, round buttons (New Chat, Send, Stop) and the result
/// card. Hover is a fill step; a press shows on the frame it lands, only the release eases.
struct AgentChipButtonStyle: ButtonStyle {
    enum Kind {
        case chip, card, circle, accentCircle
    }

    var kind = Kind.chip

    func makeBody(configuration: Configuration) -> some View {
        AgentChipButton(configuration: configuration, kind: kind)
    }
}

extension ButtonStyle where Self == AgentChipButtonStyle {
    static var agentChip: Self { AgentChipButtonStyle() }
    static var agentCard: Self { AgentChipButtonStyle(kind: .card) }
    static var agentCircle: Self { AgentChipButtonStyle(kind: .circle) }
    static var agentAccentCircle: Self { AgentChipButtonStyle(kind: .accentCircle) }
}

private struct AgentChipButton: View {
    let configuration: ButtonStyleConfiguration
    let kind: AgentChipButtonStyle.Kind

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var isAccent: Bool {
        kind == .accentCircle
    }

    var body: some View {
        configuration.label
            .font(kind == .chip ? .callout : .body.weight(.medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .chip ? EditorTheme.mediumSpacing : 0)
            .padding(.vertical, kind == .chip ? EditorTheme.tightSpacing + 2 : 0)
            .frame(width: kind == .circle || isAccent ? Self.circleSize : nil, height: kind == .circle || isAccent ? Self.circleSize : nil)
            .background(fill, in: shape)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled || isAccent ? 1 : 0.4)
            .onHover { isHovered = $0 }
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: configuration.isPressed)
            .editorMotion(EditorTheme.quickMotion, value: isHovered)
    }

    private var shape: AnyShape {
        switch kind {
        case .chip, .circle, .accentCircle: AnyShape(.capsule)
        case .card: AnyShape(.rect(cornerRadius: 14, style: .continuous))
        }
    }

    private var isLit: Bool {
        isEnabled && isHovered
    }

    private var fill: Color {
        if isAccent {
            return isEnabled ? EditorTheme.accent.opacity(configuration.isPressed ? 0.7 : isLit ? 0.85 : 1) : EditorTheme.softHairline
        }
        return Color.primary.opacity(isEnabled && configuration.isPressed ? 0.14 : isLit ? 0.1 : 0.06)
    }

    private var foreground: Color {
        if isAccent {
            return isEnabled ? .white : EditorTheme.faint
        }
        return kind == .card || isLit ? EditorTheme.ink : EditorTheme.dim
    }

    private static let circleSize: CGFloat = 28
}
