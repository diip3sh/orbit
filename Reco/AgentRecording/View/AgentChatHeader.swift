//
//  AgentChatHeader.swift
//  Reco
//

import AppKit
import SwiftUI

/// The agent panel's header beside the window's buttons: New take and the button that closes the panel, and why
/// no agent can run when none can. Its empty parts drag the window.
struct AgentChatHeader: View {
    let model: AgentRecordingViewModel

    /// Closes the panel.
    let hide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            HStack(spacing: EditorTheme.smallSpacing) {
                Spacer(minLength: WebPanel.windowButtonsWidth)
                Button("New take", action: model.startNewChat)
                    .buttonStyle(.webPill)
                    .help("Start a new conversation")
                    .disabled(model.isRunning || model.transcript.entries.isEmpty)
                Button("Hide Agent", systemImage: "sidebar.leading", action: hide)
                    .buttonStyle(EditorIconButtonStyle(diameter: 28))
                    .help("Hide the agent")
            }
            .frame(height: WebPanel.headerHeight)

            if model.available.isEmpty, let reason = model.unavailableReason ?? (model.isLookingForAgents ? "Looking for agents…" : nil) {
                Text(reason)
                    .font(.theme(.callout))
                    .foregroundStyle(EditorTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                if model.unavailableReason != nil {
                    Button(action: Self.openAgentSettings) {
                        Label("Set Up Agents…", image: "button-settings")
                    }
                    .buttonStyle(.editorSecondary)
                }
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, EditorTheme.spacing)
        .dragsWindow()
    }

    /// Opens Settings on its Agents tab.
    static func openAgentSettings() {
        UserDefaults.standard.set(AgentsSettingsView.tag, forKey: AgentsSettingsView.tabStorageKey)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
