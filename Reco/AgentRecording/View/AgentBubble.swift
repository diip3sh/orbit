//
//  AgentBubble.swift
//  Reco
//

import SwiftUI

/// A chat bubble's shape and fill: the agent's light and outlined, the user's in the accent colour, an
/// activity card quieter than both.
struct AgentBubble: ViewModifier {
    enum Role {
        case assistant, user, activity
    }

    let role: Role

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        content
            .padding(.horizontal, EditorTheme.mediumSpacing)
            .padding(.vertical, EditorTheme.smallSpacing)
            .background(fill, in: shape)
            .overlay {
                if role == .assistant {
                    shape.strokeBorder(contrast == .increased ? EditorTheme.dim : EditorTheme.hairline)
                }
            }
    }

    private var fill: Color {
        switch role {
        case .assistant: Color.primary.opacity(0.06)
        case .user: EditorTheme.accent
        case .activity: Color.primary.opacity(0.04)
        }
    }
}

/// How a bubble comes in: a spring from its own bottom corner, or just a fade with Reduce Motion.
struct AgentEntrance: ViewModifier {
    let anchor: UnitPoint

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func body(content: Content) -> some View {
        content.transition(
            reducesMotion
                ? .opacity
                : .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: anchor)).combined(with: .offset(y: 8)),
                    removal: .opacity
                )
        )
    }
}

extension View {

    /// A chat bubble in `role`'s look.
    func agentBubble(_ role: AgentBubble.Role) -> some View {
        modifier(AgentBubble(role: role))
    }

    /// Sits on the agent's side (left) or the user's, leaving room on the other, and enters from there.
    func agentSide(_ alignment: HorizontalAlignment) -> some View {
        let isUser = alignment == .trailing
        return frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            .padding(isUser ? .leading : .trailing, EditorTheme.largeSpacing + EditorTheme.spacing)
            .modifier(AgentEntrance(anchor: isUser ? .bottomTrailing : .bottomLeading))
    }
}
