//
//  AgentRecordingFailure.swift
//  Reco
//

import SwiftUI

/// Why the last run failed, with Retry, as a card on the agent's side of the chat.
struct AgentRecordingFailure: View {
    let reason: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: EditorTheme.smallSpacing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(EditorTheme.dim)
                    .accessibilityHidden(true)
                Text(reason)
                    .font(.theme(.callout))
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(action: retry) {
                Label("Retry", image: "button-retry")
            }
            .buttonStyle(.editorSecondary)
        }
        .padding(EditorTheme.mediumSpacing)
        .background(AgentChatCard.fill, in: AgentChatCard.shape)
        .overlay {
            AgentChatCard.shape.strokeBorder(WebPanel.edge)
        }
        .agentSide(.leading)
        .accessibilityElement(children: .contain)
    }
}
