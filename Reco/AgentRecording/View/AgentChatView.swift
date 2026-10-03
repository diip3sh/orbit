//
//  AgentChatView.swift
//  Reco
//

import SwiftUI

/// The Web Recording window's Agent tab (spec 0008): the conversation with a coding agent about the
/// window's page, what it did step by step, the render's progress, and the message box.
struct AgentChatView: View {
    @Bindable var model: AgentRecordingViewModel

    /// The window's page, which every message is about.
    let page: URL?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
                    if model.transcript.entries.isEmpty {
                        AgentChatEmpty()
                    }
                    ForEach(model.transcript.entries) { entry in
                        AgentChatRow(entry: entry)
                    }
                    if case .running(let agent) = model.phase {
                        AgentChatProgress(agent: agent, progress: model.progress)
                    }
                    if case .failed(let reason) = model.phase {
                        AgentRecordingFailure(reason: reason, retry: model.retry)
                            .background(EditorTheme.softHairline, in: .rect(cornerRadius: 10))
                    }
                }
                .padding(EditorTheme.spacing)
            }
            .defaultScrollAnchor(.bottom)
            .scrollIndicators(.automatic)

            Rectangle()
                .fill(EditorTheme.hairline)
                .frame(height: 1)

            AgentChatComposer(model: model, page: page)
        }
        .task { await model.refreshAgents() }
        .editorMotion(value: model.transcript)
        .editorMotion(value: model.phase)
    }
}

/// What the tab says before the first message.
private struct AgentChatEmpty: View {
    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            Label("Record with an agent", systemImage: "sparkles")
                .font(.headline)
            Text("""
                Describe the video and a coding agent records this page. You see what it looks at and plans as it \
                works; its clips stay on the timeline to change and render again, or ask it for another take.
                """)
                .font(.callout)
                .foregroundStyle(EditorTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, EditorTheme.smallSpacing)
    }
}

/// The agent at work, with the render's percent once it has started.
private struct AgentChatProgress: View {
    let agent: AgentKind
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.tightSpacing) {
            HStack(spacing: EditorTheme.smallSpacing) {
                ProgressView()
                    .controlSize(.small)
                Text(progress == nil ? "\(agent.displayName) is working…" : "Rendering…")
                    .font(.callout)
                    .foregroundStyle(EditorTheme.dim)
                if let progress {
                    Spacer()
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(EditorTheme.dim)
                }
            }
            if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
