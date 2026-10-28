//
//  AgentChipButtonStyle.swift
//  Reco
//

import SwiftUI

/// The agent chat's own buttons: the result card on the chat's faint fill with a hairline edge, and Send (Stop
/// while the agent works) on the accent fill. Hover is a fill step; a press shows on the frame it lands, only the
/// release eases.
struct AgentChipButtonStyle: ButtonStyle {
    enum Kind {
        case card, accentCircle
    }

    var kind = Kind.card
    var diameter: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        AgentChipButton(configuration: configuration, kind: kind, diameter: diameter)
    }
}

extension ButtonStyle where Self == AgentChipButtonStyle {
    static var agentCard: Self { AgentChipButtonStyle(kind: .card) }
}

private struct AgentChipButton: View {
    let configuration: ButtonStyleConfiguration
    let kind: AgentChipButtonStyle.Kind
    let diameter: CGFloat

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        switch kind {
        case .card:
            configuration.label
                .foregroundStyle(EditorTheme.ink)
                .background {
                    AgentChatCard.shape.fill(AgentChatCard.fill)
                    AgentChatCard.shape.fill(EditorTheme.ink.opacity(isEnabled && configuration.isPressed ? 0.06 : isLit ? 0.03 : 0))
                    AgentChatCard.shape.strokeBorder(WebPanel.edge)
                }
                .contentShape(AgentChatCard.shape)
                .modifier(Feedback(configuration: configuration, isHovered: $isHovered))
        case .accentCircle:
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isEnabled ? EditorTheme.onAccent : EditorTheme.faint)
                .frame(width: diameter, height: diameter)
                .background(
                    isEnabled
                        ? EditorTheme.accentFill.opacity(configuration.isPressed ? 0.7 : isLit ? 0.85 : 1)
                        : EditorTheme.ink.opacity(0.1),
                    in: .circle
                )
                .contentShape(.circle)
                .modifier(Feedback(configuration: configuration, isHovered: $isHovered))
        }
    }

    private var isLit: Bool {
        isEnabled && isHovered
    }
}

/// The press's shrink and the hover's tracking both kinds share.
private struct Feedback: ViewModifier {
    let configuration: ButtonStyleConfiguration
    @Binding var isHovered: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .onHover { isHovered = $0 }
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: configuration.isPressed)
            .editorMotion(EditorTheme.quickMotion, value: isHovered)
    }
}
