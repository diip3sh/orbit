//
//  AgentRecordingViewModelTests.swift
//  RecoTests
//

import Foundation
import Synchronization
import Testing
@testable import Reco

@MainActor
struct AgentRecordingViewModelTests {

    private let defaults = TemporaryDefaults()
    private let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    private let token = "secret-token"

    /// What the fake command line was asked to run.
    private final class Calls: Sendable {
        private let lock = Mutex<[[String]]>([])

        var arguments: [[String]] { lock.withLock { $0 } }

        func record(_ arguments: [String]) {
            lock.withLock { $0.append(arguments) }
        }
    }

    private let loginEnvironment: [String: String] = ["PATH": "/opt/bin", "HOME": "/Users/x"]

    private func connectedStore() throws -> AgentConfigStore {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: home.appending(path: ".claude.json"))
        let command = AgentServerCommand(executable: "/Applications/Reco.app/Contents/MacOS/Reco", token: token)
        let store = AgentConfigStore(home: home, command: command, bundlePath: "/Applications/Reco.app")
        try store.connect(.claudeCode)
        return store
    }

    private func makeModel(
        tools: AgentTools? = nil,
        store: AgentConfigStore? = nil,
        defaults suite: UserDefaults? = nil,
        failures: Calls = Calls(),
        environment: Result<[String: String], any Error>? = nil,
        run: @escaping AgentRecordingViewModel.RunProcess = { _, _, _, _, _ in AgentProcess.Result(end: .exited(0), stdout: "", stderr: "") }
    ) throws -> AgentRecordingViewModel {
        let tools = tools ?? AgentTools(settings: SettingsStore(defaults: defaults.make())) { _ in }
        let environment = environment ?? .success(loginEnvironment)
        return AgentRecordingViewModel(
            tools: tools,
            reportFailure: { failures.record([$0]) },
            token: token,
            defaults: suite ?? defaults.make(),
            store: try store ?? connectedStore(),
            directory: home.appending(path: "run"),
            loadEnvironment: { try environment.get() },
            isExecutable: { $0 == "/opt/bin/claude" },
            runProcess: run
        )
    }

    private func finish(_ model: AgentRecordingViewModel) async {
        for _ in 0..<200 where model.isRunning {
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    /// Blocks until cancelled, like a long agent run.
    private static let hanging: AgentRecordingViewModel.RunProcess = { _, _, _, _, _ in
        try? await Task.sleep(for: .seconds(60))
        return AgentProcess.Result(end: .cancelled, stdout: "", stderr: "")
    }

    private func request(model: String? = nil) throws -> AgentRecordingRequest {
        AgentRecordingRequest(url: try #require(WebScript.url(from: "example.com")), instructions: "", agent: .claudeCode, model: model)
    }

    // MARK: - Agents

    @Test func aConnectedAgentWhoseCommandIsFoundIsAvailableAndSelected() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let model = try makeModel()

        await model.refreshAgents()

        #expect(model.available == [.claudeCode])
        #expect(model.agent == .claudeCode)
        #expect(model.unavailableReason == nil)
    }

    @Test func claudeCodeNeedsOnlyItsCommandLineSinceEachRunBringsRecosServer() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let store = AgentConfigStore(home: home, command: AgentServerCommand(executable: "/x", token: token), bundlePath: "/Applications/Reco.app")
        let model = try makeModel(store: store)

        await model.refreshAgents()

        #expect(model.available == [.claudeCode])
        #expect(model.unavailableReason == nil)
    }

    @Test func withNoAgentToRunTheReasonSaysWhatToInstallOrConnect() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let store = AgentConfigStore(home: home, command: AgentServerCommand(executable: "/x", token: token), bundlePath: "/Applications/Reco.app")
        let model = try makeModel(store: store, environment: .success(["PATH": "/usr/bin"]))

        await model.refreshAgents()

        #expect(model.available.isEmpty)
        #expect(model.unavailableReason?.hasPrefix("Install Claude Code or Cursor's command line") == true)
    }

    @Test func anOutdatedConnectionAsksToReconnectAnAgentThatNeedsIt() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home.appending(path: ".codex"), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: home.appending(path: ".claude.json"))
        let installed = AgentServerCommand(executable: "/Applications/Reco.app/Contents/MacOS/Reco", token: token)
        let old = AgentConfigStore(home: home, command: installed, bundlePath: "/Applications/Reco.app")
        try old.connect(.codex)
        try old.connect(.claudeCode)
        let moved = AgentConfigStore(home: home, command: AgentServerCommand(executable: "/Elsewhere/Reco", token: token), bundlePath: "/Applications/Reco.app")
        let model = try makeModel(store: moved, environment: .success(["PATH": "/usr/bin"]))

        await model.refreshAgents()

        // Not Claude Code, whose runs bring Reco's server
        #expect(model.available.isEmpty)
        #expect(model.unavailableReason == "Reconnect Codex in Settings → Agents.")
    }

    @Test func aCommandMissingFromTheLoginShellIsSaidSo() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let model = try makeModel(environment: .success(["PATH": "/usr/bin"]))

        await model.refreshAgents()

        #expect(model.available.isEmpty)
        #expect(model.unavailableReason == "Claude Code is connected, but Reco couldn't find `claude` in your login shell.")
    }

    @Test func aShellThatCantBeReadIsTheReason() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let model = try makeModel(environment: .failure(AgentProcess.EnvironmentError.timedOut))

        await model.refreshAgents()

        #expect(model.available.isEmpty)
        #expect(model.unavailableReason == "Your shell took more than 10 seconds to start.")
    }

    @Test func theAgentAndModelAreRememberedAndTheModelResetsForAnAgentWithoutIt() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let suite = defaults.make()
        let first = try makeModel(defaults: suite)

        first.agent = .codex
        first.model = "gpt-6-astra"
        let second = try makeModel(defaults: suite)

        #expect(second.agent == .codex)
        #expect(second.model == "gpt-6-astra")
        #expect(second.models == AgentModelCatalog.models(for: .codex))

        second.agent = .claudeCode
        #expect(second.model == nil)
        #expect(suite.string(forKey: AgentRecordingViewModel.modelKey) == nil)
        second.model = "opus"
        second.agent = .claudeCode
        #expect(second.model == "opus")
    }

    // MARK: - Running

    @Test func submitAsksForTheAddressWhenItIsntAPage() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let model = try makeModel()
        await model.refreshAgents()

        model.address = "not a page"

        #expect(model.submit() == .address)
        #expect(!model.canRun)
        #expect(model.phase == .idle)
    }

    @Test func aRunPassesThePromptAndTheLoginEnvironmentAndEndsIdleOnSuccess() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let calls = Calls()
        let tools = AgentTools(settings: SettingsStore(defaults: defaults.make())) { _ in }
        let environments = Mutex<[String: String]>([:])
        let model = try makeModel(tools: tools) { executable, arguments, environment, _, _ in
            calls.record([executable.path(percentEncoded: false)] + arguments)
            environments.withLock { $0 = environment }
            await MainActor.run { tools.job = RenderStatus(renderID: "new", status: .done, progress: 1, movie: "/tmp/new.mov") }
            return AgentProcess.Result(end: .exited(0), stdout: "/tmp/new.mov", stderr: "")
        }
        var succeeded = false
        var recorded: AgentRecordedTake?
        model.onSucceeded = { succeeded = true }
        model.onRecorded = { recorded = $0 }
        await model.refreshAgents()
        model.address = "example.com"
        model.instructions = "Scroll down."

        #expect(model.submit() == nil)
        #expect(model.phase == .running(.claudeCode))
        await finish(model)

        let run = try #require(calls.arguments.first)
        #expect(run.first == "/opt/bin/claude")
        #expect(run[1] == "-p")
        #expect(run[2].contains("https://example.com") && run[2].contains("Scroll down."))
        #expect(environments.withLock { $0 } == loginEnvironment)
        #expect(model.phase == .idle)
        #expect(succeeded)
        #expect(recorded?.movie.path() == "/tmp/new.mov")
        #expect(recorded?.replacing == nil)
        #expect(recorded?.conversation.map(\.text) == ["Scroll down.", "/tmp/new.mov"])
    }

    @Test func aChatsFailureStaysInItsChatWithoutANotification() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let failures = Calls()
        let model = try makeModel(failures: failures) { _, _, _, _, _ in
            AgentProcess.Result(end: .exited(1), stdout: "", stderr: "Overloaded")
        }
        await model.refreshAgents()
        var asked = try request()
        asked.take = .init(movie: URL(filePath: "/m/a.mov"), steps: RecordPageRequest(url: "https://example.com", steps: []))

        model.run(asked)
        await finish(model)

        #expect(model.phase == .failed("Claude Code exited with status 1: Overloaded"))
        #expect(model.panelFailure == nil)
        #expect(failures.arguments.isEmpty)
    }

    @Test func theWorkingFolderExistsWhenAnAgentNeedsNoFilesInIt() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let existed = Mutex(false)
        // The command runs in it, whether or not the agent needs files there
        let model = try makeModel { _, _, _, directory, _ in
            existed.withLock { $0 = FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) }
            return AgentProcess.Result(end: .exited(0), stdout: "", stderr: "")
        }
        await model.refreshAgents()
        model.address = "example.com"

        #expect(model.submit() == nil)
        await finish(model)

        #expect(existed.withLock { $0 })
    }

    @Test func aSecondRunIsRefusedWhileOneIsGoing() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let calls = Calls()
        let model = try makeModel { _, arguments, _, _, _ in
            calls.record(arguments)
            return await Self.hanging(URL(filePath: "/"), [], [:], URL(filePath: "/"), .seconds(1))
        }
        await model.refreshAgents()

        model.run(try request())
        model.run(try request())
        model.address = "example.com"
        #expect(model.submit() == nil)
        try await Task.sleep(for: .milliseconds(200))
        model.cancel()

        #expect(calls.arguments.count == 1)
        #expect(model.phase == .idle)
    }

    @Test func aFailureShowsItsReasonTellsTheUserAndRetryRunsTheSameRequest() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let calls = Calls()
        let failures = Calls()
        let model = try makeModel(failures: failures) { _, arguments, _, _, _ in
            calls.record(arguments)
            return AgentProcess.Result(end: .exited(1), stdout: "", stderr: "Not logged in. Token \(token) was rejected")
        }
        await model.refreshAgents()
        let asked = try request(model: "opus")

        model.run(asked)
        await finish(model)

        let reason = "Claude Code exited with status 1: Not logged in. Token … was rejected"
        #expect(model.phase == .failed(reason))
        #expect(failures.arguments == [[reason]])
        #expect(model.lastRequest == asked)

        model.retry()
        #expect(model.phase == .running(.claudeCode))
        await finish(model)

        #expect(calls.arguments.count == 2)
        #expect(calls.arguments[0] == calls.arguments[1])
        #expect(calls.arguments[0].contains("opus"))
        #expect(model.phase == .failed(reason))
    }

    @Test func cancellingStopsTheRunWithoutAFailure() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let failures = Calls()
        let model = try makeModel(failures: failures, run: Self.hanging)
        await model.refreshAgents()
        model.run(try request())
        try await Task.sleep(for: .milliseconds(100))

        model.cancel()
        try await Task.sleep(for: .milliseconds(200))

        #expect(model.phase == .idle)
        #expect(failures.arguments.isEmpty)
    }

    @Test func theMenuBarShowsAIThenTheRendersPercent() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let tools = AgentTools(settings: SettingsStore(defaults: defaults.make())) { _ in }
        tools.job = RenderStatus(renderID: "old", status: .rendering, progress: 0.9)
        let model = try makeModel(tools: tools, run: Self.hanging)
        await model.refreshAgents()
        #expect(model.menuBarText == nil)
        #expect(model.progress == nil)

        model.run(try request())
        // The render that was there before isn't this run's
        #expect(model.menuBarText == "AI")

        tools.job = RenderStatus(renderID: "new", status: .rendering, progress: 0.42)
        #expect(model.menuBarText == "42%")
        #expect(model.progress == 0.42)

        model.cancel()
        #expect(model.menuBarText == nil)
    }
}
