//
//  AgentChatHeader.swift
//  Reco
//

import AppKit
import SwiftUI

/// The agent chat's title with the agent and model that run it, or why none can.
struct AgentChatHeader: View {
    @Bindable var model: AgentRecordingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            HStack(spacing: EditorTheme.tightSpacing) {
                Text("Agent")
                    .font(.theme(.headline))
                Spacer(minLength: EditorTheme.smallSpacing)
                if !model.available.isEmpty {
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
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize(horizontal: false, vertical: true)
            .disabled(model.isRunning)

            if model.available.isEmpty, let reason = model.unavailableReason ?? (model.isLookingForAgents ? "Looking for agents…" : nil) {
                Text(reason)
                    .font(.theme(.caption))
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
        .padding(.horizontal, EditorTheme.spacing)
        .padding(.vertical, EditorTheme.smallSpacing)
    }

    /// Opens Settings on its Agents tab.
    static func openAgentSettings() {
        UserDefaults.standard.set(AgentsSettingsView.tag, forKey: AgentsSettingsView.tabStorageKey)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
