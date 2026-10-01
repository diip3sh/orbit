//
//  AgentsSettingsViewModel.swift
//  Reco
//

import Foundation

/// State and intents of Settings → Agents: the server's status and a row per agent.
@MainActor
@Observable
final class AgentsSettingsViewModel {

    /// One agent in the list.
    struct Row: Identifiable, Equatable {
        var kind: AgentKind
        var state: AgentConnectionState

        var id: String { kind.id }

        var statusText: String {
            switch state {
            case .notInstalled: "Not found"
            case .notConnected: "Not connected"
            case .connected: "Connected"
            case .outdated: "Out of date"
            }
        }

        /// The row's button, or `nil` when there's nothing to do.
        var actionTitle: String? {
            switch state {
            case .notInstalled: nil
            case .notConnected: "Connect"
            case .connected: "Disconnect"
            case .outdated: "Reconnect"
            }
        }
    }

    private(set) var rows: [Row] = []

    /// Why the last connect or disconnect failed.
    var errorMessage: String?

    let server: AgentBridgeServer

    @ObservationIgnored private let store: AgentConfigStore

    init(server: AgentBridgeServer, store: AgentConfigStore = AgentConfigStore()) {
        self.server = server
        self.store = store
    }

    var serverStatus: String {
        server.listenError ?? (server.isListening ? "Listening" : "Starting")
    }

    var hasServerError: Bool {
        server.listenError != nil
    }

    /// The latest render an agent started, in a few words.
    var renderSummary: String {
        guard let job = server.tools.job else { return "None yet" }
        switch job.status {
        case .rendering: return "Rendering \(job.progress.formatted(.percent.precision(.fractionLength(0))))"
        case .done: return job.movie.map { URL(filePath: $0).lastPathComponent } ?? "Done"
        case .failed: return "Failed"
        }
    }

    /// Reads every agent's settings again, e.g. when the tab opens.
    func refresh() {
        rows = AgentKind.allCases.map { Row(kind: $0, state: store.state(of: $0)) }
    }

    /// Connects, disconnects or reconnects `row`'s agent, as its button says.
    func perform(_ row: Row) {
        do {
            if row.state == .connected {
                try store.disconnect(row.kind)
            } else {
                try store.connect(row.kind)
            }
        } catch {
            errorMessage = "\(row.kind.displayName): \(error.localizedDescription)"
        }
        refresh()
    }
}
