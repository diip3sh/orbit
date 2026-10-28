//
//  AgentChatComposer.swift
//  Reco
//

import SwiftUI

/// The agent chat's message box: a field for what the video should show, or a change to the last take, the agent
/// and model that run it, and Send (Stop while the agent works); under it a few things to start from.
struct AgentChatComposer: View {
    @Bindable var model: AgentRecordingViewModel
    let page: URL?

    @State private var message = ""
    @FocusState private var isFocused: Bool

    /// A chip's title and the message it puts in the box.
    private typealias Suggestion = (title: String, message: String)

    private static let firstSuggestions: [Suggestion] = [
        ("Whole page", "Tour the whole page"),
        ("Main menu", "Hover the main menu"),
        ("Main button", "Click the main button")
    ]

    private static let changeSuggestions: [Suggestion] = [
        ("Slower", "Make it slower"),
        ("Add a zoom", "Add a zoom on the main button"),
        ("Whole page", "Show the whole page")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
            VStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
                TextField(placeholder, text: $message, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.theme(.title3))
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .onSubmit(send)
                    // Nothing to type for without a page or an agent, so nothing typed is lost
                    .disabled(!canType)

                HStack(spacing: EditorTheme.smallSpacing) {
                    if !model.available.isEmpty {
                        AgentModelMenu(model: model)
                    }
                    Spacer(minLength: 0)
                    sendButton
                }
            }
            .padding(.top, EditorTheme.spacing)
            .padding(.horizontal, EditorTheme.spacing)
            .padding(.bottom, EditorTheme.mediumSpacing)
            .background(AgentChatCard.fill, in: AgentChatCard.shape)
            .overlay {
                AgentChatCard.shape.strokeBorder(isFocused ? EditorTheme.faint : WebPanel.edge)
            }
            .editorMotion(EditorTheme.quickMotion, value: isFocused)
            .contentShape(AgentChatCard.shape)
            .onTapGesture { isFocused = canType }

            ChipFlow(spacing: EditorTheme.smallSpacing) {
                ForEach(suggestions, id: \.title) { suggestion in
                    Button(suggestion.title) {
                        message = suggestion.message
                        isFocused = true
                    }
                    .buttonStyle(.webPill)
                    .help(suggestion.message)
                    .disabled(!canType)
                }
            }

            if page == nil {
                Text("Load a page first: type its address above the preview.")
                    .font(.theme(.caption))
                    .foregroundStyle(EditorTheme.dim)
            }
        }
        .padding([.horizontal, .bottom], WebPanel.padding)
        .onAppear { isFocused = page != nil }
    }

    private var sendButton: some View {
        Button(model.isRunning ? "Stop" : "Send", systemImage: model.isRunning ? "stop.fill" : "arrow.up") {
            if model.isRunning {
                model.cancel()
            } else {
                send()
            }
        }
        .labelStyle(.iconOnly)
        .contentTransition(.symbolEffect(.replace))
        .buttonStyle(AgentChipButtonStyle(kind: .accentCircle, diameter: 32))
        .keyboardShortcut(model.isRunning ? KeyboardShortcut(".", modifiers: .command) : .defaultAction)
        .help(model.isRunning ? "Stop the agent (⌘.)" : "Send (↩); ⌥↩ for a new line")
        .disabled(!model.isRunning && !canSend)
        .editorMotion(EditorTheme.quickMotion, value: model.isRunning)
    }

    /// A first message describes the video; later ones change it.
    private var placeholder: String {
        model.transcript.entries.isEmpty ? "Describe the video…" : "Describe the change…"
    }

    private var suggestions: [Suggestion] {
        model.transcript.entries.isEmpty ? Self.firstSuggestions : Self.changeSuggestions
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

/// The agent and model that run the chat, on a pill that opens a menu of both.
private struct AgentModelMenu: View {
    @Bindable var model: AgentRecordingViewModel

    var body: some View {
        Menu {
            Picker("Agent", selection: $model.agent) {
                ForEach(model.available) { kind in
                    Text(kind.displayName).tag(AgentKind?.some(kind))
                }
            }
            Picker("Model", selection: $model.model) {
                Text("Default").tag(String?.none)
                ForEach(model.models, id: \.self) { name in
                    Text(name).tag(String?.some(name))
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(EditorTheme.accent)
                Text(model.agent?.displayName ?? "Agent")
                    .font(.theme(.callout, weight: .medium))
                    .foregroundStyle(EditorTheme.ink)
                Text(model.model ?? "Default")
                    .font(.theme(.callout))
                    .foregroundStyle(EditorTheme.dim)
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(EditorTheme.dim)
            }
            .lineLimit(1)
            .padding(.leading, EditorTheme.smallSpacing + 2)
            .padding(.trailing, EditorTheme.smallSpacing + 2)
            .frame(height: 28)
            .webField()
            .contentShape(.capsule)
        }
        .pickerStyle(.inline)
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .disabled(model.isRunning)
        .help("The agent and model that make the take")
    }
}
