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
        let isEmpty = chat.conversation.isEmpty && chat.pendingMessage == nil

        ZStack {
            if isEmpty {
                AgentChatEmptyState { chat.draft = $0 }
                    .transition(.materialize)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: EditorTheme.spacing) {
                        ForEach(chat.conversation) { message in
                            AgentChatMessageRow(role: message.role, text: message.text)
                        }
                        if let pending = chat.pendingMessage {
                            AgentChatMessageRow(role: .user, text: pending)
                                .transition(.materialize(offset: 12))
                        }
                        if let status = chat.status {
                            AgentChatStatus(status: status)
                                .transition(.materialize(offset: 8))
                        }
                        if let failure = chat.failure {
                            AgentChatFailure(reason: failure, retry: chat.retry)
                                .transition(.materialize(offset: 8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EditorTheme.spacing)
                }
                .scrollIndicators(.never)
                .defaultScrollAnchor(.bottom)
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .editorBar(edge: .bottom) {
            AgentChatComposer(chat: chat)
        }
        .editorMotion(value: isEmpty)
        .editorMotion(value: chat.pendingMessage)
        .editorMotion(value: chat.status == nil)
        .editorMotion(value: chat.failure)
    }
}
