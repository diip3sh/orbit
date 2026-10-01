//
//  AgentRunOutcome.swift
//  Reco
//

import Foundation

/// How an agent's command line ended.
nonisolated enum AgentProcessEnd: Equatable, Sendable {
    case exited(Int32)
    case timedOut
    case cancelled
    case launchFailed(String)
}

/// What a run of an agent came to, from the user's point of view.
nonisolated enum AgentRunOutcome: Equatable, Sendable {

    /// A render finished: the movie's path. The editor has opened it already.
    case succeeded(movie: String)
    case failed(reason: String)
    case cancelled

    /// How long a run may take, and so how long to wait for its render.
    ///
    /// ponytail: a 30 s apple.com take at 2x renders in 1 to 2 minutes, plus the agent's turns, but
    /// linear.app at 310 ms a frame needs 18 minutes for 60 s. Make it a setting if a take hits this.
    static let timeLimit = Duration.seconds(15 * 60)

    /// Decides the outcome from how the process ended and the bridge's latest render.
    ///
    /// A render is this run's when it isn't the one that was there when it started
    /// (`startingRenderID`). Rules, in order: cancelling wins; a finished render is a success even if
    /// the agent then exited badly (the editor has opened, and Retry would record again); then the
    /// process's own failures; then a failed render, or none at all.
    static func classify(
        end: AgentProcessEnd, agent: AgentKind, job: RenderStatus?, startingRenderID: String?, outputReason: String
    ) -> AgentRunOutcome {
        let render = job.flatMap { $0.renderID == startingRenderID ? nil : $0 }
        let reason = outputReason.isEmpty ? "" : ": \(outputReason)"
        if end == .cancelled {
            return .cancelled
        }
        if let render, render.status == .done {
            return .succeeded(movie: render.movie ?? "")
        }
        switch end {
        case .timedOut:
            return .failed(reason: "The agent didn't finish within 15 minutes.")
        case .launchFailed(let message):
            return .failed(reason: message)
        case .exited(let status) where status != 0:
            return .failed(reason: "\(agent.displayName) exited with status \(status)\(reason)")
        case .exited, .cancelled:
            if let error = render?.error, render?.status == .failed {
                return .failed(reason: error)
            }
            return .failed(reason: "The agent finished without recording.\(outputReason.isEmpty ? "" : " \(outputReason)")")
        }
    }
}
