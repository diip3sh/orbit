//
//  AgentRecordingRequest.swift
//  Reco
//

import Foundation

/// What the user asked a coding agent to record from the Record with AI Agent panel (spec 0007).
nonisolated struct AgentRecordingRequest: Equatable, Sendable {
    var url: URL
    var instructions: String
    var agent: AgentKind

    /// The model to use, or `nil` for the agent's own default.
    var model: String?

    /// What the video shows when the user said nothing.
    static let defaultInstructions = "No instructions: hover and click the page's main call to action, then scroll through the page."

    /// The task for the agent. It starts with "Record" so a command line can't read it as a flag.
    var prompt: String {
        let wanted = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
            Record a video of this web page with Reco: \(url.absoluteString)

            What the video should show:
            \(wanted.isEmpty ? Self.defaultInstructions : wanted)

            Use only the reco MCP tools: call inspect_page, then record_page, then call render_status with its render_id until \
            the status is done or failed. Don't ask questions; choose sensible steps yourself. When it's done, reply with the \
            movie's path only. If it fails, reply with the error.
            """
    }
}
