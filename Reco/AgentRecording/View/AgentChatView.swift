//
//  AgentChatView.swift
//  Reco
//

import SwiftUI

/// The editor's agent chat (spec 0008): the conversation that made the take, how a run is going, and
/// a box to ask for changes, which has the agent record the take again.
struct AgentChatView: View {
    @Bindable var chat: AgentChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
                    if chat.conversation.isEmpty, chat.pendingMessage == nil {
                        Text("""
                            Tell the agent how to record this page differently, like “slower”, “also hover the pricing table” or \
                            “end on the footer”. It records a new take and shows it here, in the same style.
                            """)
                            .font(.callout)
                            .foregroundStyle(EditorTheme.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(chat.conversation) { message in
                        AgentChatMessageRow(role: message.role, text: message.text)
                    }
                    if let pending = chat.pendingMessage {
                        AgentChatMessageRow(role: .user, text: pending)
                            .transition(.opacity)
                    }
                    if let status = chat.status {
                        AgentChatStatus(status: status, cancel: chat.cancel)
                            .transition(.opacity)
                    }
                    if let failure = chat.failure {
                        AgentChatMessageRow(role: .failure, text: failure)
                            .transition(.opacity)
                        Button("Retry", systemImage: "arrow.clockwise", action: chat.retry)
                            .buttonStyle(.editorGhost)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .scrollIndicators(.never)
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .editorMotion(value: chat.pendingMessage)
            .editorMotion(value: chat.failure)

            Rectangle()
                .fill(EditorTheme.hairline)
                .frame(height: 1)

            AgentChatComposer(chat: chat)
        }
    }
}

/// How a run is going, with Cancel.
private struct AgentChatStatus: View {
    let status: String
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            ProgressView()
                .controlSize(.small)
            Text(status)
                .monospacedDigit()
                .foregroundStyle(EditorTheme.dim)
                .contentTransition(.numericText())
            Spacer()
            Button("Cancel", action: cancel)
                .buttonStyle(.editorGhost)
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }
}
