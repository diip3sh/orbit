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

    /// Closes the panel.
    let hide: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    var body: some View {
        VStack(spacing: 0) {
            AgentChatHeader(model: model, hide: hide)

            ScrollView {
                VStack(alignment: .leading, spacing: EditorTheme.spacing) {
                    if model.transcript.entries.isEmpty {
                        AgentAssistantBubble(text: greeting)
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
                .lineSpacing(4)
                .padding(.horizontal, 20)
                .padding(.vertical, EditorTheme.smallSpacing)
                .animation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion, value: model.transcript)
                .animation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion, value: model.phase)
                .animation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion, value: model.lastMovie)
                .animation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion, value: model.progress == nil)
            }
            .defaultScrollAnchor(.bottom)
            // A short conversation starts under the header, not above the message box
            .defaultScrollAnchor(.top, for: .alignment)
            .scrollIndicators(.automatic)

            AgentChatComposer(model: model, page: page)
        }
        .task { await model.refreshAgents() }
    }

    private var greeting: String {
        let host = page.flatMap { $0.host(percentEncoded: false) }.map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 }
        return "Tell me what the video should show. I'll explore \(host ?? "the page") and plan the beats."
    }
}
