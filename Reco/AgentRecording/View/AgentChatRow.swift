//
//  AgentChatRow.swift
//  Reco
//

import SwiftUI

/// One thing in the agent chat: the user's message on the right, the agent's words on the left, or the
/// Reco tools it used as one card, each going, done or failed.
struct AgentChatRow: View {
    let group: AgentTranscript.Group

    var body: some View {
        switch group {
        case .request(let entry):
            Text(entry.text)
                .textSelection(.enabled)
                .foregroundStyle(.white)
                .agentBubble(.user)
                .agentSide(.trailing)
                .accessibilityLabel("You: \(entry.text)")
        case .reply(let entry):
            AgentAssistantBubble(text: entry.text)
        case .tools(let steps):
            VStack(alignment: .leading, spacing: EditorTheme.tightSpacing) {
                ForEach(steps) { step in
                    AgentToolStep(entry: step)
                }
            }
            .agentBubble(.activity)
            .agentSide(.leading)
            .accessibilityElement(children: .contain)
        }
    }
}

/// What the agent said.
struct AgentAssistantBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .textSelection(.enabled)
            .agentBubble(.assistant)
            .agentSide(.leading)
            .accessibilityLabel("Agent: \(text)")
    }
}

/// One tool the agent used, with whether it's going, done or failed.
private struct AgentToolStep: View {
    let entry: AgentTranscript.Entry

    var body: some View {
        if case .tool(let state) = entry.kind {
            HStack(spacing: EditorTheme.smallSpacing) {
                AgentToolState(state: state)
                    .frame(width: 14, height: 14)
                Text(entry.text)
                    .font(.callout)
                    .foregroundStyle(state == .failed ? EditorTheme.ink : EditorTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
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
            LineIcon(.hugeiconsCheckmarkCircle)
                .foregroundStyle(EditorTheme.dim)
                .accessibilityLabel("Done")
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(EditorTheme.ink)
                .accessibilityLabel("Failed")
        }
    }
}
