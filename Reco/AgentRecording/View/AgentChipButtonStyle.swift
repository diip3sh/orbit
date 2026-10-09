//
//  AgentChipButtonStyle.swift
//  Reco
//

import SwiftUI

/// The agent chat's small buttons: suggestion chips, round buttons (New Chat, Send, Stop) and the result
/// card, on the control fill (the card on a surface) with a hairline edge; Send is the accent fill. Hover is a
/// fill step; a press shows on the frame it lands, only the release eases.
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
            .font(kind == .chip ? .theme(.callout) : .theme(weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .chip ? EditorTheme.mediumSpacing : 0)
            .padding(.vertical, kind == .chip ? EditorTheme.tightSpacing + 2 : 0)
            .frame(width: kind == .circle || isAccent ? Self.circleSize : nil, height: kind == .circle || isAccent ? Self.circleSize : nil)
            .background {
                shape.fill(fill)
                if !isAccent {
                    shape.fill(EditorTheme.ink.opacity(isEnabled && configuration.isPressed ? 0.1 : isLit ? 0.06 : 0))
                    // Inside the edge, as `strokeBorder` would draw it; `AnyShape` isn't insettable
                    shape.stroke(EditorTheme.hairline).padding(0.5)
                }
            }
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
        case .card: AnyShape(.rect(cornerRadius: EditorTheme.radius, style: .continuous))
        }
    }

    private var isLit: Bool {
        isEnabled && isHovered
    }

    private var fill: Color {
        if isAccent {
            return isEnabled ? EditorTheme.accentFill.opacity(configuration.isPressed ? 0.7 : isLit ? 0.85 : 1) : EditorTheme.control
        }
        return kind == .card ? EditorTheme.surface : EditorTheme.control
    }

    private var foreground: Color {
        if isAccent {
            return isEnabled ? EditorTheme.onAccent : EditorTheme.faint
        }
        return kind == .card || isLit ? EditorTheme.ink : EditorTheme.dim
    }

    private static let circleSize: CGFloat = 28
}
