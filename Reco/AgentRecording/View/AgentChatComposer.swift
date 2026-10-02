//
//  AgentChatComposer.swift
//  Reco
//

import SwiftUI

/// The agent chat's message box: the message, and under it the agent, the model and Record,
/// which is Stop while a run goes; or why no agent can run, with Set Up Agents….
struct AgentChatComposer: View {
    @Bindable var chat: AgentChatViewModel

    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var runner = chat.runner

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            TextField("Ask for changes…", text: $chat.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isFocused)
                .onSubmit(chat.send)
                .padding(.horizontal, EditorTheme.tightSpacing)
                .padding(.top, EditorTheme.tightSpacing)

            if runner.available.isEmpty {
                Text(runner.unavailableReason ?? (runner.isLookingForAgents ? "Looking for agents…" : ""))
                    .font(.caption)
                    .foregroundStyle(EditorTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, EditorTheme.tightSpacing)
            }

            HStack(spacing: EditorTheme.smallSpacing) {
                if !runner.available.isEmpty {
                    Menu {
                        Picker("Agent", selection: $runner.agent) {
                            ForEach(runner.available) { kind in
                                Text(kind.displayName).tag(AgentKind?.some(kind))
                            }
                        }
                        .labelsHidden()
                    } label: {
                        Text(runner.agent?.displayName ?? "Agent")
                    }
                    .fixedSize()
                    Menu {
                        Picker("Model", selection: $runner.model) {
                            Text("Default").tag(String?.none)
                            ForEach(runner.models, id: \.self) { name in
                                Text(name).tag(String?.some(name))
                            }
                        }
                        .labelsHidden()
                    } label: {
                        Text(runner.model ?? "Default")
                    }
                    .fixedSize()
                } else if runner.unavailableReason != nil {
                    Button("Set Up Agents…", action: AgentRecordingFooter.openAgentSettings)
                        .buttonStyle(.editorGhost)
                }

                Spacer(minLength: 0)

                Button(chat.isRunning ? "Stop" : "Record", systemImage: chat.isRunning ? "stop.fill" : "arrow.up") {
                    if chat.isRunning {
                        chat.cancel()
                    } else {
                        chat.send()
                    }
                }
                .buttonStyle(EditorIconButtonStyle(isProminent: true, diameter: 28))
                .contentTransition(.symbolEffect(.replace))
                .bold()
                .disabled(!chat.isRunning && !chat.canSend)
                .help(chat.isRunning ? "Stop the agent" : "Record the page again as asked (↩; ⌥↩ for a new line)")
            }
            .pickerStyle(.inline)
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(EditorTheme.smallSpacing)
        // A fill, not glass: the box lies on the side panel's glass
        .background(.primary.opacity(isFocused ? 0.08 : 0.05), in: EditorTheme.trayShape)
        .overlay {
            EditorTheme.trayShape.strokeBorder(isFocused ? EditorTheme.faint : EditorTheme.hairline)
        }
        .editorMotion(EditorTheme.quickMotion, value: isFocused)
        .padding(EditorTheme.mediumSpacing)
        // A suggestion, or a stopped run's message, lands in the box ready to send
        .onChange(of: chat.draft) { old, new in
            if old.isEmpty, !new.isEmpty {
                isFocused = true
            }
        }
    }
}
