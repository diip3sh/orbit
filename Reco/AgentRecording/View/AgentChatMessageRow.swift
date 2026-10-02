//
//  AgentChatMessageRow.swift
//  Reco
//

import SwiftUI

/// One message of the agent chat: the user's on the right on a quiet fill, the agent's on the left,
/// a failure dimmed with a warning sign.
struct AgentChatMessageRow: View {
    let role: AgentChatMessage.Role
    let text: String

    var body: some View {
        switch role {
        case .user:
            Text(text)
                .lineSpacing(2)
                .textSelection(.enabled)
                .padding(.horizontal, EditorTheme.mediumSpacing)
                .padding(.vertical, EditorTheme.smallSpacing)
                .background(.primary.opacity(0.08), in: .rect(cornerRadius: 16, style: .continuous))
                .padding(.leading, EditorTheme.largeSpacing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("You: \(text)")
        case .agent:
            Label {
                Text(text)
                    .lineSpacing(2)
                    .textSelection(.enabled)
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(EditorTheme.dim)
            }
            .accessibilityLabel("Agent: \(text)")
        case .failure:
            Label {
                Text(text)
                    .font(.callout)
                    .foregroundStyle(EditorTheme.dim)
                    .textSelection(.enabled)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(EditorTheme.dim)
            }
            .accessibilityLabel("Recording failed: \(text)")
        }
    }
}
