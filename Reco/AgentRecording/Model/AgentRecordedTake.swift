//
//  AgentRecordedTake.swift
//  Reco
//

import Foundation

/// A take an agent run recorded, to open in the editor with the conversation that made it (spec 0008).
nonisolated struct AgentRecordedTake: Equatable, Sendable {
    var movie: URL

    /// The take the run changed, whose editor window shows this one instead, or `nil` for a new one.
    var replacing: URL?

    /// The request's conversation, then its instructions and the agent's reply.
    var conversation: [AgentChatMessage]

    /// The longest reply kept; a chatty agent's last message can run long.
    static let maximumReply = 1000

    /// - Parameter output: What the agent printed, its last message when it prints text only.
    init(movie: URL, request: AgentRecordingRequest, output: String) {
        self.movie = movie
        replacing = request.take?.movie
        let instructions = request.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let reply = OutputTail.plain(output).trimmingCharacters(in: .whitespacesAndNewlines)
        conversation = request.conversation + [
            AgentChatMessage(role: .user, text: instructions.isEmpty ? request.defaultInstructions : instructions),
            AgentChatMessage(role: .agent, text: reply.isEmpty ? (request.motion == nil ? "Recorded." : "Done.") : String(reply.prefix(Self.maximumReply)))
        ]
    }
}
