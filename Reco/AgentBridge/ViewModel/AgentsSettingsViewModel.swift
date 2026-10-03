//
//  AgentsSettingsViewModel.swift
//  Reco
//

import AppKit

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
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let usableAgents: () async -> Set<AgentKind>

    /// Agents the user disconnected, which aren't connected again on their own.
    private static let declinedKey = "declinedAgents"

    /// - Parameter usableAgents: The agents that can actually run here, which alone are connected on
    ///   their own: a settings folder can outlive its agent (Codex, OpenCode and Gemini folders were left
    ///   on a Mac without their command lines, and got connected).
    init(
        server: AgentBridgeServer, store: AgentConfigStore = AgentConfigStore(), defaults: UserDefaults = .standard,
        usableAgents: @escaping () async -> Set<AgentKind> = AgentsSettingsViewModel.usableAgents
    ) {
        self.server = server
        self.store = store
        self.defaults = defaults
        self.usableAgents = usableAgents
    }

    /// Agents whose command line is on the login shell's `PATH`, and Claude Desktop when its app is installed.
    nonisolated static func usableAgents() async -> Set<AgentKind> {
        let environment = (try? await AgentProcess.loginEnvironment()) ?? [:]
        return Set(AgentKind.allCases.filter { kind in
            guard let name = AgentInvocation.executableName(for: kind) else {
                return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.anthropic.claudefordesktop") != nil
            }
            return LoginEnvironment.resolve(name, in: environment) { FileManager.default.isExecutableFile(atPath: $0) } != nil
        })
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
        case .planned: return "On the timeline"
        case .done: return job.movie.map { URL(filePath: $0).lastPathComponent } ?? "Done"
        case .failed: return "Failed"
        }
    }

    /// Reads every agent's settings again, e.g. after a connect or disconnect.
    func refresh() {
        rows = AgentKind.allCases.map { Row(kind: $0, state: store.state(of: $0)) }
    }

    /// When the tab opens: connects the agents that can run here, or brings their entry up to date,
    /// unless the user disconnected them. One that can't be (Reco run from Downloads, a symbolic link)
    /// keeps its button, which says why.
    func connectUsableAgents() async {
        refresh()
        let usable = await usableAgents()
        let declined = Set(defaults.stringArray(forKey: Self.declinedKey) ?? [])
        for kind in usable where !declined.contains(kind.id) && [.notConnected, .outdated].contains(store.state(of: kind)) {
            try? store.connect(kind)
        }
        refresh()
    }

    /// Connects, disconnects or reconnects `row`'s agent, as its button says.
    func perform(_ row: Row) {
        do {
            var declined = Set(defaults.stringArray(forKey: Self.declinedKey) ?? [])
            if row.state == .connected {
                try store.disconnect(row.kind)
                declined.insert(row.kind.id)
            } else {
                try store.connect(row.kind)
                declined.remove(row.kind.id)
            }
            defaults.set(declined.sorted(), forKey: Self.declinedKey)
        } catch {
            errorMessage = "\(row.kind.displayName): \(error.localizedDescription)"
        }
        refresh()
    }
}
