//
//  AgentsSettingsViewModelTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

@MainActor
struct AgentsSettingsViewModelTests {

    private let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    private let defaults = TemporaryDefaults()

    private func model(defaults suite: UserDefaults) -> AgentsSettingsViewModel {
        let store = AgentConfigStore(home: home, command: AgentServerCommand(executable: "/x", token: "t"), bundlePath: "/Applications/Reco.app")
        let tools = AgentTools(settings: SettingsStore(defaults: defaults.make())) { _ in }
        return AgentsSettingsViewModel(server: AgentBridgeServer(tools: tools), store: store, defaults: suite) { [.cursor] }
    }

    private func state(of kind: AgentKind, in model: AgentsSettingsViewModel) -> AgentConnectionState? {
        model.rows.first { $0.kind == kind }?.state
    }

    @Test func agentsThatCanRunAreConnectedUnlessTheUserDisconnectedThem() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home.appending(path: ".cursor"), withIntermediateDirectories: true)
        // A folder left without its command line isn't connected
        try FileManager.default.createDirectory(at: home.appending(path: ".gemini"), withIntermediateDirectories: true)
        let suite = defaults.make()

        let settings = model(defaults: suite)
        await settings.connectUsableAgents()
        #expect(state(of: .cursor, in: settings) == .connected)
        #expect(state(of: .gemini, in: settings) == .notConnected)
        #expect(state(of: .codex, in: settings) == .notInstalled)

        try #require(settings.rows.first { $0.kind == .cursor }).perform(on: settings)
        settings.refresh()
        #expect(state(of: .cursor, in: settings) == .notConnected)
        // A new window remembers it too
        let again = model(defaults: suite)
        await again.connectUsableAgents()
        #expect(state(of: .cursor, in: again) == .notConnected)
    }
}

private extension AgentsSettingsViewModel.Row {
    func perform(on model: AgentsSettingsViewModel) {
        model.perform(self)
    }
}
