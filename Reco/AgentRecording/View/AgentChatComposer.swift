//
//  AgentChatComposer.swift
//  Reco
//

import SwiftUI

/// The agent chat's message box with Record, and the agent and model below it; or why no agent can
/// run, with Set Up Agents….
struct AgentChatComposer: View {
    @Bindable var chat: AgentChatViewModel

    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var runner = chat.runner

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            HStack(alignment: .bottom, spacing: EditorTheme.smallSpacing) {
                TextField("Ask for changes…", text: $chat.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .onSubmit(chat.send)
                    .padding(.vertical, EditorTheme.tightSpacing)
                Button("Record", systemImage: "arrow.up", action: chat.send)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.editorPrimary)
                    // The editor's button style shows the icon alone, which VoiceOver would read as "button"
                    .accessibilityLabel("Record")
                    .disabled(!chat.canSend)
                    .help("Record the page again as asked (↩; ⌥↩ for a new line)")
            }
            .padding(EditorTheme.smallSpacing)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isFocused ? EditorTheme.faint : EditorTheme.hairline)
            }

            if runner.available.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text(runner.unavailableReason ?? (runner.isLookingForAgents ? "Looking for agents…" : ""))
                        .font(.caption)
                        .foregroundStyle(EditorTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if runner.unavailableReason != nil {
                        Button("Set Up Agents…", action: AgentRecordingFooter.openAgentSettings)
                            .buttonStyle(.editorGhost)
                    }
                }
            } else {
                HStack(spacing: EditorTheme.tightSpacing) {
                    Picker("Agent", selection: $runner.agent) {
                        ForEach(runner.available) { kind in
                            Text(kind.displayName).tag(AgentKind?.some(kind))
                        }
                    }
                    .fixedSize()
                    Picker("Model", selection: $runner.model) {
                        Text("Default").tag(String?.none)
                        ForEach(runner.models, id: \.self) { name in
                            Text(name).tag(String?.some(name))
                        }
                    }
                    .fixedSize()
                    Spacer(minLength: 0)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
            }
        }
        .padding()
    }
}
