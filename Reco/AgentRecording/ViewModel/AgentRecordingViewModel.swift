//
//  AgentRecordingViewModel.swift
//  Reco
//

import Foundation

/// State and intents of the Record with AI Agent panel (spec 0007): the address and instructions the
/// user types, which agent and model run them, and how the run is going. It also runs what the
/// editor's agent chat asks (spec 0008): one run at a time, from either.
///
/// A run starts the agent's command line with only Reco's MCP tools allowed. The agent inspects the
/// page and records it through ``AgentTools``. This type only watches that render, to show it and to
/// tell success from failure, and hands the take to ``onRecorded`` when the run ends.
@MainActor
@Observable
final class AgentRecordingViewModel {

    enum Phase: Equatable {
        case idle
        case running(AgentKind)
        case failed(String)
    }

    /// An input the Return key can ask for.
    enum Field {
        case address
        case instructions
    }

    var address = ""
    var instructions = ""

    /// The agent the panel runs.
    var agent: AgentKind? {
        didSet {
            defaults.set(agent?.rawValue, forKey: Self.agentKey)
            if let model, !models.contains(model) {
                self.model = nil
            }
        }
    }

    /// The model to ask the agent for, or `nil` for its own default.
    var model: String? {
        didSet { defaults.set(model, forKey: Self.modelKey) }
    }

    /// Connected agents whose command line Reco found.
    private(set) var available: [AgentKind] = []

    /// Why no agent can run, with what to do about it.
    private(set) var unavailableReason: String?
    private(set) var isLookingForAgents = false
    private(set) var phase = Phase.idle

    /// What the last run asked, for Retry.
    private(set) var lastRequest: AgentRecordingRequest?

    /// Whether the panel is on screen, for its entrance and exit.
    var isPresented = false

    /// Called when a run ends with a movie, after ``onRecorded``.
    @ObservationIgnored var onSucceeded: (() -> Void)?

    /// Called with the take a run recorded, to open it in the editor.
    @ObservationIgnored var onRecorded: ((AgentRecordedTake) -> Void)?

    /// How a command line is run: executable, arguments, environment, working folder, time limit.
    typealias RunProcess = @Sendable (URL, [String], [String: String], URL, Duration) async -> AgentProcess.Result

    @ObservationIgnored let tools: AgentTools
    @ObservationIgnored private let reportFailure: (String) -> Void
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let token: String
    @ObservationIgnored private let store: AgentConfigStore
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let loadEnvironment: @Sendable () async throws -> [String: String]
    @ObservationIgnored private let isExecutable: (String) -> Bool
    @ObservationIgnored private let runProcess: RunProcess
    @ObservationIgnored private var environment: [String: String]?
    @ObservationIgnored private var task: Task<Void, Never>?

    /// The render that was the bridge's latest when the run started, which isn't the run's.
    private var startingRenderID: String?

    static let agentKey = "agentRecordingAgent"
    static let modelKey = "agentRecordingModel"
    private static let pollInterval = Duration.milliseconds(250)

    /// - Parameters:
    ///   - tools: The bridge's tools, whose latest render is the run's progress.
    ///   - reportFailure: Tells the user a run failed while the panel may be closed.
    ///   - token: The bridge token, kept out of any reason shown.
    init(
        tools: AgentTools,
        reportFailure: @escaping (String) -> Void,
        token: String,
        defaults: UserDefaults = .standard,
        store: AgentConfigStore = AgentConfigStore(),
        directory: URL = URL.recoSupport.appending(path: "AgentRun"),
        loadEnvironment: @escaping @Sendable () async throws -> [String: String] = { try await AgentProcess.loginEnvironment() },
        isExecutable: @escaping (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        runProcess: @escaping RunProcess = { executable, arguments, environment, directory, timeout in
            await AgentProcess.run(executable: executable, arguments: arguments, environment: environment, directory: directory, timeout: timeout)
        }
    ) {
        self.tools = tools
        self.reportFailure = reportFailure
        self.token = token
        self.defaults = defaults
        self.store = store
        self.directory = directory
        self.loadEnvironment = loadEnvironment
        self.isExecutable = isExecutable
        self.runProcess = runProcess
        agent = defaults.string(forKey: Self.agentKey).flatMap(AgentKind.init(rawValue:))
        model = defaults.string(forKey: Self.modelKey)
    }

    // MARK: - State

    var isRunning: Bool {
        if case .running = phase { true } else { false }
    }

    /// The models to choose from for the agent, besides its default.
    var models: [String] {
        agent.map(AgentModelCatalog.models(for:)) ?? []
    }

    /// Whether Record can start a run now.
    var canRun: Bool {
        !isRunning && agent != nil && WebScript.url(from: address) != nil
    }

    /// How far this run's render is, from 0 to 1, once it has started.
    var progress: Double? {
        guard isRunning, let job = tools.job, job.renderID != startingRenderID, job.status == .rendering else { return nil }
        return job.progress
    }

    /// Why the panel's last run failed; a chat's failure shows in its chat.
    var panelFailure: String? {
        guard lastRequest?.take == nil, case .failed(let reason) = phase else { return nil }
        return reason
    }

    /// What the menu bar shows while a run is going: the render's percent once it has started, "AI"
    /// before, and nothing otherwise.
    var menuBarText: String? {
        guard isRunning else { return nil }
        return progress?.formatted(.percent.precision(.fractionLength(0))) ?? "AI"
    }

    // MARK: - Agents

    /// Looks for agents again, e.g. when the panel opens; the last answer stays meanwhile. Claude Code
    /// and Cursor need only their command line, since each run gives them Reco's server; the others
    /// need connecting in Settings → Agents.
    func refreshAgents() async {
        isLookingForAgents = true
        defer { isLookingForAgents = false }
        let headless = AgentKind.allCases.filter { AgentInvocation.executableName(for: $0) != nil }
        let connected = headless.filter { store.state(of: $0) == .connected }
        do {
            environment = try await loadEnvironment()
        } catch {
            if environment == nil {
                return setAvailable([], reason: error.localizedDescription)
            }
        }
        let environment = environment ?? [:]
        let found = headless.filter { kind in
            (AgentInvocation.bringsOwnServer(kind) || connected.contains(kind)) && executable(for: kind, in: environment) != nil
        }
        guard found.isEmpty else { return setAvailable(found, reason: nil) }
        if let first = connected.first, let command = AgentInvocation.executableName(for: first) {
            setAvailable([], reason: "\(first.displayName) is connected, but Reco couldn't find `\(command)` in your login shell.")
        } else if let outdated = headless.first(where: { !AgentInvocation.bringsOwnServer($0) && store.state(of: $0) == .outdated }) {
            setAvailable([], reason: "Reconnect \(outdated.displayName) in Settings → Agents.")
        } else {
            setAvailable([], reason: "Install Claude Code or Cursor's command line, or connect Codex, OpenCode, Gemini CLI or Grok Build "
                + "in Settings → Agents.")
        }
    }

    private func setAvailable(_ kinds: [AgentKind], reason: String?) {
        available = kinds
        unavailableReason = reason
        if let agent, kinds.contains(agent) { return }
        agent = kinds.first
    }

    private func executable(for kind: AgentKind, in environment: [String: String]) -> URL? {
        AgentInvocation.executableName(for: kind).flatMap { LoginEnvironment.resolve($0, in: environment, isExecutable: isExecutable) }
    }

    // MARK: - Running

    /// Runs the typed request if it's complete; otherwise the field to put the cursor in.
    func submit() -> Field? {
        guard !isRunning else { return nil }
        guard let url = WebScript.url(from: address) else { return .address }
        guard let agent else { return nil }
        run(AgentRecordingRequest(url: url, instructions: instructions, agent: agent, model: model))
        return nil
    }

    /// Starts `request`, unless a run is going.
    func run(_ request: AgentRecordingRequest) {
        guard !isRunning else { return }
        lastRequest = request
        startingRenderID = tools.job?.renderID
        phase = .running(request.agent)
        task = Task { await execute(request) }
    }

    /// Runs the last request again, e.g. from the failed state or the notification's Retry.
    func retry() {
        if let lastRequest {
            run(lastRequest)
        }
    }

    /// Stops the agent. A render it already started carries on.
    func cancel() {
        guard isRunning else { return }
        task?.cancel()
        task = nil
        phase = .idle
    }

    private func execute(_ request: AgentRecordingRequest) async {
        let deadline = ContinuousClock.now + AgentRunOutcome.timeLimit
        var outcome: AgentRunOutcome
        var output = ""
        do {
            (outcome, output) = try await perform(request, deadline: deadline)
        } catch {
            outcome = Task.isCancelled ? .cancelled : .failed(reason: error.localizedDescription)
        }
        guard !Task.isCancelled else { return }
        switch outcome {
        case .succeeded(let movie):
            phase = .idle
            let reply = token.isEmpty ? output : output.replacing(token, with: "…")
            onRecorded?(AgentRecordedTake(movie: URL(filePath: movie), request: request, output: reply))
            onSucceeded?()
        case .cancelled:
            phase = .idle
        case .failed(let reason):
            phase = .failed(reason)
            // A chat shows its failure where the user asked
            if request.take == nil {
                reportFailure(reason)
            }
        }
    }

    /// Runs `request`'s command line and waits for its render: how it ended and what it printed.
    private func perform(_ request: AgentRecordingRequest, deadline: ContinuousClock.Instant) async throws -> (AgentRunOutcome, String) {
        let environment: [String: String]
        if let cached = self.environment {
            environment = cached
        } else {
            environment = try await loadEnvironment()
        }
        guard let invocation = AgentInvocation.make(for: request, in: directory, server: store.command),
              let executable = executable(for: request.agent, in: environment) else {
            return (.failed(reason: "Reco couldn't find \(request.agent.displayName)'s command in your login shell."), "")
        }
        // The command runs in it, so it must exist even when the agent needs no files there
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (path, contents) in invocation.files {
            let file = directory.appending(path: path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(contents.utf8).write(to: file, options: .atomic)
        }
        let result = await runProcess(
            executable, invocation.arguments, environment.merging(invocation.environment) { $1 }, directory, max(.seconds(1), ContinuousClock.now.duration(to: deadline))
        )
        var end = result.end
        // The agent may stop waiting for a render that carries on
        if case .exited = end, !(await waitForRender(until: deadline)) {
            end = Task.isCancelled ? .cancelled : .timedOut
        }
        let outcome = AgentRunOutcome.classify(
            end: end, agent: request.agent, job: tools.job, startingRenderID: startingRenderID,
            outputReason: OutputTail.reason(stdout: result.stdout, stderr: result.stderr, redacting: [token])
        )
        return (outcome, result.stdout)
    }

    /// Waits while this run's render goes on; `false` when `deadline` or a cancel came first.
    private func waitForRender(until deadline: ContinuousClock.Instant) async -> Bool {
        while let job = tools.job, job.renderID != startingRenderID, job.status == .rendering {
            guard !Task.isCancelled, ContinuousClock.now < deadline else { return false }
            try? await Task.sleep(for: Self.pollInterval)
        }
        return true
    }
}
