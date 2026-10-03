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
                        .foregroundStyle(viewModel.hasServerError ? .red : .primary)
                }
                LabeledContent("Agents connected now", value: viewModel.server.sessionCount, format: .number)
                LabeledContent("Latest render", value: viewModel.renderSummary)
            }

            Section {
                ForEach(viewModel.rows) { row in
                    LabeledContent(row.kind.displayName) {
                        HStack {
                            Text(row.statusText)
                                .foregroundStyle(.secondary)
                            if let title = row.actionTitle {
                                Button(title) {
                                    viewModel.perform(row)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Agents")
            } footer: {
                Text("Restart an agent after connecting it. Reco adds itself as an MCP server named reco to the agent's own settings.")
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { viewModel.refresh() }
        .alert("Couldn't Update the Agent", isPresented: errorShown) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }
}
