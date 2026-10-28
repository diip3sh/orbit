//
//  AgentBubble.swift
//  Reco
//

import SwiftUI

/// A chat row's look: the user's message in a bubble on the faint ink fill with its corner by the edge tucked in,
/// the agent's words and its activity as plain text on the panel.
struct AgentBubble: ViewModifier {
    enum Role {
        case assistant, user, activity
    }

    let role: Role

    func body(content: Content) -> some View {
        switch role {
        case .user:
            content
                .padding(.horizontal, EditorTheme.spacing)
                .padding(.vertical, EditorTheme.mediumSpacing)
                .background(
                    AgentChatCard.fill,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: EditorTheme.largeRadius, bottomLeadingRadius: EditorTheme.largeRadius,
                        bottomTrailingRadius: EditorTheme.smallRadius, topTrailingRadius: EditorTheme.largeRadius,
                        style: .continuous
                    )
                )
        case .assistant, .activity:
            content
        }
    }
}

/// The fill and shape the chat's cards share (the message box, results, failures, the user's bubble).
enum AgentChatCard {
    static let fill = EditorTheme.ink.opacity(0.07)
    static let shape = RoundedRectangle(cornerRadius: EditorTheme.largeRadius, style: .continuous)
}

/// How a row comes in: a spring from its own bottom corner, or just a fade with Reduce Motion.
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

    /// A chat row in `role`'s look.
    func agentBubble(_ role: AgentBubble.Role) -> some View {
        modifier(AgentBubble(role: role))
    }

    /// Sits on the agent's side (left, the panel's width) or the user's, leaving room before it, and enters from there.
    func agentSide(_ alignment: HorizontalAlignment) -> some View {
        let isUser = alignment == .trailing
        return frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            .padding(.leading, isUser ? EditorTheme.largeSpacing + EditorTheme.spacing : 0)
            .modifier(AgentEntrance(anchor: isUser ? .bottomTrailing : .bottomLeading))
    }
}
