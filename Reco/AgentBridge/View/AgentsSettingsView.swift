//
//  AgentsSettingsView.swift
//  Reco
//

import SwiftUI

/// Settings → Agents: connect coding agents so they can record a web page from its address.
struct AgentsSettingsView: View {

    /// The defaults key of the Settings window's selected tab, and this tab's value for it.
    static let tabStorageKey = "settingsTab"
    static let tag = "agents"

    @State private var viewModel: AgentsSettingsViewModel

    init(server: AgentBridgeServer) {
        _viewModel = State(initialValue: AgentsSettingsViewModel(server: server))
    }

    var body: some View {
        Form {
            Section("Server") {
                LabeledContent("Status") {
                    Text(viewModel.serverStatus)
                        .foregroundStyle(viewModel.hasServerError ? EditorTheme.danger : EditorTheme.ink)
                }
                LabeledContent("Agents connected now", value: viewModel.server.sessionCount, format: .number)
                LabeledContent("Latest render", value: viewModel.renderSummary)
            }

            Section {
                ForEach(viewModel.rows) { row in
                    LabeledContent(row.kind.displayName) {
                        HStack {
                            Text(row.statusText)
                                .foregroundStyle(statusColor(of: row.state))
                            if let title = row.actionTitle {
                                Button {
                                    viewModel.perform(row)
                                } label: {
                                    if row.state == .connected {
                                        Text(title).foregroundStyle(EditorTheme.danger)
                                    } else {
                                        Text(title)
                                    }
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Agents")
            } footer: {
                Text("Restart an agent after connecting it. Orbit adds itself as an MCP server named reco to the agent's own settings.")
            }
        }
        .settingsForm()
        .task { viewModel.refresh() }
        .alert("Couldn't Update the Agent", isPresented: errorShown) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func statusColor(of state: AgentConnectionState) -> Color {
        switch state {
        case .connected: EditorTheme.success
        case .notConnected, .outdated: EditorTheme.warning
        case .notInstalled: EditorTheme.dim
        }
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }
}
