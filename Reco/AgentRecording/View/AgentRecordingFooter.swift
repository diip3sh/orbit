//
//  AgentRecordingFooter.swift
//  Reco
//

import AppKit
import SwiftUI

/// The panel's bottom row: the agent and model with Record, why none can run, or the run's progress
/// with Cancel.
struct AgentRecordingFooter: View {
    @Bindable var model: AgentRecordingViewModel
    let submit: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            if case .running(let agent) = model.phase {
                ProgressView()
                    .controlSize(.small)
                Text(model.activity ?? "\(agent.displayName) is \(model.lastRequest?.mode == .launch ? "making the video" : "recording")…")
                    .monospacedDigit()
                Spacer()
                Button("Cancel", action: model.cancel)
                    .buttonStyle(.editorGhost)
            } else if model.available.isEmpty {
                Text(model.unavailableReason ?? (model.isLookingForAgents ? "Looking for agents…" : ""))
                    .font(.callout)
                    .foregroundStyle(EditorTheme.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if model.unavailableReason != nil {
                    Button("Set Up Agents…", action: Self.openAgentSettings)
                        .buttonStyle(.editorGhost)
                }
            } else {
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
                Spacer()
                Text("↩ Record   ⌥↩ New Line")
                    .font(.caption)
                    .foregroundStyle(contrast == .increased ? EditorTheme.dim : EditorTheme.faint)
                Button("Record", systemImage: "sparkles", action: submit)
                    .buttonStyle(.editorPrimary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canRun)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .padding(.horizontal, EditorTheme.spacing)
        .padding(.vertical, EditorTheme.smallSpacing)
        .frame(minHeight: 44)
    }

    /// Opens Settings on its Agents tab.
    static func openAgentSettings() {
        UserDefaults.standard.set(AgentsSettingsView.tag, forKey: AgentsSettingsView.tabStorageKey)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
