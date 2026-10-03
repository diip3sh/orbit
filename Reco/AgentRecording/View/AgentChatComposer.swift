//
//  AgentChatComposer.swift
//  Reco
//

import AppKit
import SwiftUI

/// The agent chat's message box: what the video should show, or a change to the last take; the agent
/// and model; New Chat; and Send, or Stop while the agent works.
struct AgentChatComposer: View {
    @Bindable var model: AgentRecordingViewModel
    let page: URL?

    @State private var message = ""
    @FocusState private var isFocused: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            TextField(placeholder, text: $message, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...6)
                .focused($isFocused)
                .onSubmit(send)
                // Nothing to type for without a page or an agent, so nothing typed is lost
                .disabled(model.isRunning || page == nil || model.agent == nil)

            if model.available.isEmpty {
                HStack(spacing: EditorTheme.smallSpacing) {
                    Text(model.unavailableReason ?? (model.isLookingForAgents ? "Looking for agents…" : ""))
                        .font(.caption)
                        .foregroundStyle(EditorTheme.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if model.unavailableReason != nil {
                        Button("Set Up Agents…", action: Self.openAgentSettings)
                            .buttonStyle(.editorGhost)
                    }
                }
            } else {
                HStack(spacing: EditorTheme.tightSpacing) {
                    Picker("Agent", selection: $model.agent) {
                        ForEach(model.available) { kind in
                            Text(kind.displayName).tag(AgentKind?.some(kind))
                        }
                    }
                    .fixedSize()
                    .disabled(model.isRunning)
                    Picker("Model", selection: $model.model) {
                        Text("Default").tag(String?.none)
                        ForEach(model.models, id: \.self) { name in
                            Text(name).tag(String?.some(name))
                        }
                    }
                    .fixedSize()
                    .disabled(model.isRunning)
                    Spacer(minLength: 0)
                    Button("New Chat", systemImage: "square.and.pencil", action: model.startNewChat)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.editorGhost)
                        .help("Start a new conversation")
                        .disabled(model.isRunning || model.transcript.entries.isEmpty)
                    // Send turns into Stop in the same place while the agent works
                    if model.isRunning {
                        Button("Stop", systemImage: "stop.fill", action: model.cancel)
                            .labelStyle(.iconOnly)
                            .buttonStyle(.editorPrimary)
                            .keyboardShortcut(".", modifiers: .command)
                            .help("Stop the agent (⌘.)")
                    } else {
                        Button("Send", systemImage: "arrow.up", action: send)
                            .labelStyle(.iconOnly)
                            .buttonStyle(.editorPrimary)
                            .keyboardShortcut(.defaultAction)
                            .help("Send (↩); ⌥↩ for a new line")
                            .disabled(!canSend)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            if page == nil {
                Text("Load a page first: type its address above the preview.")
                    .font(.caption)
                    .foregroundStyle(contrast == .increased ? EditorTheme.dim : EditorTheme.faint)
            }
        }
        .padding(EditorTheme.spacing)
        .onAppear { isFocused = page != nil }
    }

    /// A first message describes the video; later ones change it.
    private var placeholder: String {
        model.transcript.entries.isEmpty
            ? "Describe the video: hover Pricing, click Start free, scroll to the FAQ…"
            : "Ask for a change: slower scroll, click Sign in too…"
    }

    /// A page, an agent and something asked.
    private var canSend: Bool {
        page != nil && model.agent != nil && !model.isRunning && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend, let page else { return }
        model.send(message, about: page)
        message = ""
    }

    /// Opens Settings on its Agents tab.
    static func openAgentSettings() {
        UserDefaults.standard.set(AgentsSettingsView.tag, forKey: AgentsSettingsView.tabStorageKey)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
