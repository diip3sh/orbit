//
//  AgentChatComposer.swift
//  Reco
//

import SwiftUI

/// The agent chat's message box: a field for what the video should show, or a change to the last take, with
/// Send (Stop while the agent works), and under it New Chat and a few things to start from.
struct AgentChatComposer: View {
    let model: AgentRecordingViewModel
    let page: URL?

    @State private var message = ""
    @FocusState private var isFocused: Bool

    private static let suggestions = ["Tour the whole page", "Hover the main menu", "Click the main button", "Scroll to the end"]

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            let shape = RoundedRectangle(cornerRadius: EditorTheme.smallRadius, style: .continuous)
            HStack(alignment: .bottom, spacing: EditorTheme.smallSpacing) {
                TextField(placeholder, text: $message, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .onSubmit(send)
                    // Nothing to type for without a page or an agent, so nothing typed is lost
                    .disabled(!canType)
                    .padding(.vertical, EditorTheme.tightSpacing + 2)
                Button(model.isRunning ? "Stop" : "Send", systemImage: model.isRunning ? "stop.fill" : "arrow.up") {
                    if model.isRunning {
                        model.cancel()
                    } else {
                        send()
                    }
                }
                .labelStyle(.iconOnly)
                .contentTransition(.symbolEffect(.replace))
                .buttonStyle(.agentAccentCircle)
                .keyboardShortcut(model.isRunning ? KeyboardShortcut(".", modifiers: .command) : .defaultAction)
                .help(model.isRunning ? "Stop the agent (⌘.)" : "Send (↩); ⌥↩ for a new line")
                .disabled(!model.isRunning && !canSend)
                .editorMotion(EditorTheme.quickMotion, value: model.isRunning)
            }
            .padding(.leading, EditorTheme.mediumSpacing)
            .padding(.trailing, EditorTheme.tightSpacing)
            .padding(.vertical, EditorTheme.tightSpacing)
            .background(EditorTheme.surface, in: shape)
            .overlay {
                shape.strokeBorder(outline)
                    .editorMotion(EditorTheme.quickMotion, value: isFocused)
            }

            ChipFlow(spacing: EditorTheme.smallSpacing) {
                Button("New Chat", systemImage: "arrow.counterclockwise", action: model.startNewChat)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.agentCircle)
                    .help("Start a new conversation")
                    .disabled(model.isRunning || model.transcript.entries.isEmpty)
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        message = suggestion
                        isFocused = true
                    }
                    .buttonStyle(.agentChip)
                    .disabled(!canType)
                }
            }

            if page == nil {
                Text("Load a page first: type its address above the preview.")
                    .font(.theme(.caption))
                    .foregroundStyle(EditorTheme.dim)
            }
        }
        .padding(EditorTheme.spacing)
        .onAppear { isFocused = page != nil }
    }

    private var outline: Color {
        if isFocused {
            return EditorTheme.accent.opacity(0.6)
        }
        return EditorTheme.hairline
    }

    /// A first message describes the video; later ones change it.
    private var placeholder: String {
        model.transcript.entries.isEmpty ? "Describe the video…" : "Ask for a change…"
    }

    private var canType: Bool {
        !model.isRunning && page != nil && model.agent != nil
    }

    /// A page, an agent and something asked.
    private var canSend: Bool {
        canType && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend, let page else { return }
        model.send(message, about: page)
        message = ""
    }
}
