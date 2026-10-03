//
//  AgentChatRow.swift
//  Reco
//

import SwiftUI

/// One line of the agent chat: the user's message on the right, the agent's words, or a Reco tool it
/// used with whether that's going, done or failed.
struct AgentChatRow: View {
    let entry: AgentTranscript.Entry

    var body: some View {
        switch entry.kind {
        case .request:
            Text(entry.text)
                .textSelection(.enabled)
                .padding(.horizontal, EditorTheme.mediumSpacing)
                .padding(.vertical, EditorTheme.smallSpacing)
                .background(EditorTheme.softHairline, in: .rect(cornerRadius: 12))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, EditorTheme.largeSpacing)
        case .reply:
            Text(entry.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .tool(let state):
            HStack(spacing: EditorTheme.smallSpacing) {
                AgentToolState(state: state)
                    .frame(width: 14, height: 14)
                Text(entry.text)
                    .font(.callout)
                    .foregroundStyle(state == .failed ? EditorTheme.ink : EditorTheme.dim)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// A spinner while a tool runs, then a tick, or a cross when it failed.
private struct AgentToolState: View {
    let state: AgentTranscript.Entry.ToolState

    var body: some View {
        switch state {
        case .running:
            ProgressView()
                .controlSize(.mini)
                .accessibilityLabel("Running")
        case .done:
            LineIcon(.iconsaxTickCircle)
                .foregroundStyle(EditorTheme.dim)
                .accessibilityLabel("Done")
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(EditorTheme.ink)
                .accessibilityLabel("Failed")
        }
    }
}
