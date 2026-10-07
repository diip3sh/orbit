//
//  AgentChatViewModelTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Synchronization
import Testing
@testable import Reco

@MainActor
struct AgentChatViewModelTests {

    private let defaults = TemporaryDefaults()
    private let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    private var movie: URL {
        folder.appending(path: "Reco_Web_1.mov")
    }

    /// What the fake command line was asked to run.
    private final class Calls: Sendable {
        private let lock = Mutex<[[String]]>([])

        var arguments: [[String]] { lock.withLock { $0 } }

        func record(_ arguments: [String]) {
            lock.withLock { $0.append(arguments) }
        }
    }

    /// A runner whose agent is Claude Code, found at `/opt/bin/claude`, running `run` as its command line.
    private func runner(run: @escaping AgentRecordingViewModel.RunProcess) async throws -> AgentRecordingViewModel {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = AgentConfigStore(home: folder, command: AgentServerCommand(executable: "/x", token: "t"), bundlePath: "/Applications/Reco.app")
        let runner = AgentRecordingViewModel(
            tools: AgentTools(settings: SettingsStore(defaults: defaults.make())) { _ in },
            reportFailure: { _ in },
            token: "t",
            defaults: defaults.make(),
            store: store,
            directory: folder.appending(path: "run"),
            loadEnvironment: { ["PATH": "/opt/bin"] },
            isExecutable: { $0 == "/opt/bin/claude" },
            runProcess: run
        )
        await runner.refreshAgents()
        return runner
    }

    private func finish(_ runner: AgentRecordingViewModel) async {
        for _ in 0..<200 where runner.isRunning {
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    private func writeTake(conversation: [AgentChatMessage] = []) async throws -> WebTake {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var script = WebScript()
        script.url = URL(string: "https://example.com")
        script.pointer = [PointerClip(range: 1..<2.5, action: .hover, target: WebTarget(selector: "#buy", point: .zero))]
        let take = WebTake(script: script, conversation: conversation)
        try await take.write(for: movie)
        return take
    }

    private static let failing: AgentRecordingViewModel.RunProcess = { _, _, _, _, _ in
        AgentProcess.Result(end: .exited(1), stdout: "", stderr: "Overloaded")
    }

    // MARK: - Loading

    @Test func readsTheTakesScriptAndConversation() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let take = try await writeTake(conversation: [AgentChatMessage(role: .user, text: "Hover Buy.")])
        let chat = AgentChatViewModel(movie: movie, runner: try await runner(run: Self.failing))

        await chat.load()

        #expect(chat.isAvailable)
        #expect(chat.script == take.script)
        #expect(chat.conversation == take.conversation)
    }

    @Test func aConversationHandedOverByARunIsSavedWithTheTake() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        _ = try await writeTake()
        let conversation = [AgentChatMessage(role: .user, text: "Hover Buy."), AgentChatMessage(role: .agent, text: "Done.")]
        let chat = AgentChatViewModel(movie: movie, runner: try await runner(run: Self.failing), conversation: conversation)

        await chat.load()

        for _ in 0..<40 where try await WebTake.read(for: movie)?.conversation != conversation {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(try await WebTake.read(for: movie)?.conversation == conversation)
    }

    @Test func aRecordingThatIsntAWebTakeHasNoChat() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let chat = AgentChatViewModel(movie: movie, runner: try await runner(run: Self.failing))

        await chat.load()

        #expect(!chat.isAvailable)
        chat.draft = "Slower."
        #expect(!chat.canSend)
    }

    // MARK: - Sending

    @Test func sendingRecordsTheTakeAgainWithItsStepsAndTheConversation() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let take = try await writeTake(conversation: [AgentChatMessage(role: .user, text: "Hover Buy.")])
        let runner = try await runner { _, _, _, _, _ in
            try? await Task.sleep(for: .seconds(60))
            return AgentProcess.Result(end: .cancelled, stdout: "", stderr: "")
        }
        let chat = AgentChatViewModel(movie: movie, runner: runner)
        let other = AgentChatViewModel(movie: folder.appending(path: "other.mov"), runner: runner)
        await chat.load()
        chat.draft = "Slower, please."

        chat.send()

        let request = try #require(runner.lastRequest)
        #expect(request.instructions == "Slower, please.")
        #expect(request.url.absoluteString == "https://example.com")
        #expect(request.take == AgentRecordingRequest.Take(movie: movie, steps: RecordPageRequest(script: take.script)))
        #expect(request.conversation == take.conversation)
        #expect(chat.draft.isEmpty)
        #expect(chat.isRunning && chat.pendingMessage == "Slower, please.")
        #expect(chat.status == "Claude Code is writing the steps…")
        // One run at a time, and only this chat's shows here
        #expect(!other.isRunning && other.pendingMessage == nil)
        chat.draft = "And faster."
        #expect(!chat.canSend)

        chat.cancel()
        #expect(!chat.isRunning)
        #expect(chat.draft == "And faster.")
    }

    @Test func cancellingPutsTheMessageBackInAnEmptyBox() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        _ = try await writeTake()
        let runner = try await runner { _, _, _, _, _ in
            try? await Task.sleep(for: .seconds(60))
            return AgentProcess.Result(end: .cancelled, stdout: "", stderr: "")
        }
        let chat = AgentChatViewModel(movie: movie, runner: runner)
        await chat.load()
        chat.draft = "Slower."
        chat.send()

        chat.cancel()

        #expect(chat.draft == "Slower.")
        #expect(chat.pendingMessage == nil)
    }

    @Test func aFailureShowsWithItsMessageAndStaysInTheConversationWhenAskingAgain() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        _ = try await writeTake()
        let calls = Calls()
        let runner = try await runner { _, arguments, _, _, _ in
            calls.record(arguments)
            return AgentProcess.Result(end: .exited(1), stdout: "", stderr: "Overloaded")
        }
        let chat = AgentChatViewModel(movie: movie, runner: runner)
        await chat.load()
        chat.draft = "Slower."
        chat.send()
        await finish(runner)

        let reason = "Claude Code exited with status 1: Overloaded"
        #expect(chat.failure == reason)
        #expect(chat.pendingMessage == "Slower.")

        chat.retry()
        await finish(runner)
        #expect(calls.arguments.count == 2)
        #expect(chat.conversation.isEmpty)

        chat.draft = "Faster."
        chat.send()
        await finish(runner)

        #expect(chat.conversation.map(\.role) == [.user, .failure])
        #expect(chat.conversation.map(\.text) == ["Slower.", reason])
        #expect(runner.lastRequest?.conversation == chat.conversation)
        #expect(chat.pendingMessage == "Faster.")
    }
}
