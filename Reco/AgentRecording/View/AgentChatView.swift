//
//  AgentChatView.swift
//  Reco
//

import SwiftUI

/// The Web Recording window's agent panel (spec 0008): the conversation with a coding agent about the
/// window's page, what it did step by step, the render's progress and result, and the message box.
struct AgentChatView: View {
    @Bindable var model: AgentRecordingViewModel

    /// The window's page, which every message is about.
    let page: URL?

    /// Opens a movie in the editor.
    let openMovie: (URL) -> Void

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    var body: some View {
        VStack(spacing: 0) {
            AgentChatHeader(model: model)

            Rectangle()
                .fill(EditorTheme.hairline)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
                    if model.transcript.entries.isEmpty {
                        AgentAssistantBubble(text: "Describe the video you want, and I'll explore this page and record it.")
                    }
                    ForEach(model.transcript.groups) { group in
                        AgentChatRow(group: group)
                    }
                    if case .running(let agent) = model.phase {
                        if let progress = model.progress {
                            AgentChatProgress(progress: progress)
                        } else {
                            AgentTypingIndicator(agent: agent)
                        }
                    }
                    if case .failed(let reason) = model.phase {
                        AgentRecordingFailure(reason: reason, retry: model.retry)
                    }
                    if let movie = model.lastMovie, !model.isRunning, !model.transcript.entries.isEmpty {
                        AgentChatResult(movie: movie) { openMovie(movie) }
                    }
                }
                .padding(EditorTheme.spacing)
                .animation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion, value: model.transcript)
                .animation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion, value: model.phase)
                .animation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion, value: model.lastMovie)
                .animation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion, value: model.progress == nil)
            }
            .defaultScrollAnchor(.bottom)
            .scrollIndicators(.automatic)

            AgentChatComposer(model: model, page: page)
        }
        .task { await model.refreshAgents() }
    }
}
