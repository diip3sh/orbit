//
//  AgentChatViewModel.swift
//  Reco
//

import Foundation
import OSLog

/// The agent chat of an editor window showing a web take (spec 0008): the conversation that made the
/// take, and a message box that has the agent record it again with changes.
///
/// Runs go through ``AgentRecordingViewModel``, one at a time with the panel's. Each request carries
/// the take's steps and the conversation, so any agent can change the take without a session of
/// its own. When a run records, the window shows the new take with this conversation.
@MainActor
@Observable
final class AgentChatViewModel {

    /// The take this chat is about.
    let movie: URL
    let runner: AgentRecordingViewModel

    /// The take's script, or `nil` while it loads and for recordings that aren't web takes.
    private(set) var script: WebScript?
    private(set) var conversation: [AgentChatMessage]
    var draft = ""

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "AgentChatViewModel")

    /// - Parameter conversation: What the run that recorded the take handed over, saved with the
    ///   take once it's read; empty to read the take's own.
    init(movie: URL, runner: AgentRecordingViewModel, conversation: [AgentChatMessage] = []) {
        self.movie = movie
        self.runner = runner
        self.conversation = conversation
    }

    /// Reads the take's script and conversation, and looks for agents if nobody has yet.
    func load() async {
        do {
            guard let take = try await WebTake.read(for: movie) else { return }
            script = take.script
            if conversation.isEmpty {
                conversation = take.conversation
            } else if conversation != take.conversation {
                save()
            }
        } catch {
            logger.error("Couldn't read the script of \(self.movie.lastPathComponent): \(error.localizedDescription)")
            return
        }
        if runner.available.isEmpty, !runner.isLookingForAgents {
            await runner.refreshAgents()
        }
    }

    // MARK: - State

    /// Whether the take can be recorded again: it's a web take with a page.
    var isAvailable: Bool {
        script?.url != nil
    }

    /// Whether the run going on, or the last one, is this chat's.
    private var isOwnRun: Bool {
        runner.lastRequest?.take?.movie == movie
    }

    var isRunning: Bool {
        runner.isRunning && isOwnRun
    }

    /// Why this chat's last run failed, until the next one.
    var failure: String? {
        guard isOwnRun, case .failed(let reason) = runner.phase else { return nil }
        return reason
    }

    /// What the user asked in the run that's going on or failed, shown after the conversation.
    var pendingMessage: String? {
        isRunning || failure != nil ? runner.lastRequest?.instructions : nil
    }

    /// What the run is doing, while it runs.
    var status: String? {
        guard isRunning, case .running(let agent) = runner.phase else { return nil }
        if let progress = runner.progress {
            return "Recording… \(progress.formatted(.percent.precision(.fractionLength(0))))"
        }
        if let page = runner.tools.inspecting {
            return "Looking at \(page.host(percentEncoded: false) ?? page.absoluteString)…"
        }
        return "\(agent.displayName) is writing the steps…"
    }

    var canSend: Bool {
        !runner.isRunning && isAvailable && runner.agent != nil && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Intents

    /// Asks the agent to record the take again as the draft says.
    func send() {
        guard canSend, let script, let url = script.url, let agent = runner.agent else { return }
        // A failed request stays in the conversation, so the agent knows what didn't work
        if let failure, let asked = runner.lastRequest?.instructions {
            conversation += [AgentChatMessage(role: .user, text: asked), AgentChatMessage(role: .failure, text: failure)]
            save()
        }
        let take = AgentRecordingRequest.Take(movie: movie, steps: RecordPageRequest(script: script))
        runner.run(AgentRecordingRequest(url: url, instructions: draft, agent: agent, model: runner.model, take: take, conversation: conversation))
        draft = ""
    }

    func retry() {
        guard failure != nil else { return }
        runner.retry()
    }

    /// Stops the run and puts its message back in the box.
    func cancel() {
        guard isRunning else { return }
        if draft.isEmpty {
            draft = runner.lastRequest?.instructions ?? ""
        }
        runner.cancel()
    }

    /// Writes the conversation into the take's file.
    private func save() {
        let (movie, conversation, logger) = (movie, conversation, logger)
        Task {
            do {
                guard var take = try await WebTake.read(for: movie) else { return }
                take.conversation = conversation
                try await take.write(for: movie)
            } catch {
                logger.error("Couldn't save the conversation of \(movie.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
}
