//
//  AgentRecordingViewModel+Chat.swift
//  Reco
//

import Foundation

// MARK: - Chat

/// The Web Recording window's Agent tab (spec 0008): messages about the window's page, follow-ups in
/// the same conversation, and the transcript the agent's stream fills in.
extension AgentRecordingViewModel {

    /// Asks the agent to record `page` as `message` says; a follow-up when it already recorded in this
    /// chat, so it changes that recording instead of starting over.
    func send(_ message: String, about page: URL) {
        guard !isRunning, let agent else { return }
        address = page.absoluteString
        instructions = message
        run(AgentRecordingRequest(url: page, instructions: message, agent: agent, model: model, resuming: transcript.sessionID(for: agent), rendersVideo: false))
    }

    /// Runs `work`, handing it a line handler that turns `agent`'s streamed output into the transcript,
    /// in order, on the main actor; returns once both are done.
    func streamingTranscript<Result: Sendable>(
        of agent: AgentKind, _ work: (@escaping @Sendable (Data) -> Void) async -> Result
    ) async -> Result {
        guard AgentStreamEvent.streams(agent) else { return await work { _ in } }
        let (events, continuation) = AsyncStream.makeStream(of: AgentStreamEvent.self)
        let reader = Task { @MainActor [weak self] in
            for await event in events {
                self?.applyToTranscript(event, from: agent)
            }
        }
        let result = await work { line in
            for event in AgentStreamEvent.parse(line, agent: agent) {
                continuation.yield(event)
            }
        }
        continuation.finish()
        await reader.value
        return result
    }
}
