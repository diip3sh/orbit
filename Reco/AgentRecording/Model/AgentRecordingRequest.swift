//
//  AgentRecordingRequest.swift
//  Reco
//

import Foundation

/// What the user asked a coding agent to record: from the Record with AI Agent panel (spec 0007),
/// or from the agent chat of a web take in the editor, to record it again with changes (spec 0008).
nonisolated struct AgentRecordingRequest: Equatable, Sendable {
    var url: URL
    var instructions: String
    var agent: AgentKind

    /// The model to use, or `nil` for the agent's own default.
    var model: String?

    /// The take the chat asks to change, or `nil` for a new one.
    var take: Take?

    /// The conversation before these instructions, oldest first.
    var conversation: [AgentChatMessage] = []

    /// A take to record again: its movie, and the `record_page` arguments that record it as it is.
    nonisolated struct Take: Equatable, Sendable {
        var movie: URL
        var steps: RecordPageRequest
    }

    /// What the video shows when the user said nothing.
    static let defaultInstructions = "No instructions: hover and click the page's main call to action, then scroll through the page."

    /// The task for the agent. It starts with "Record" so a command line can't read it as a flag.
    var prompt: String {
        let wanted = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = ["Record a video of this web page with Reco: \(url.absoluteString)"]
        if let take {
            parts.append("The current video was recorded with these record_page arguments:\n\(Self.json(take.steps))")
        }
        if !conversation.isEmpty {
            parts.append("The conversation so far:\n" + conversation.map(Self.line).joined(separator: "\n"))
        }
        parts.append((take == nil ? "What the video should show:\n" : "What the user asks now:\n") + (wanted.isEmpty ? Self.defaultInstructions : wanted))
        let change = take == nil ? "" : "Record the whole video again with record_page, changing only what the user asks and keeping "
            + "the other steps; reuse their selectors, and call inspect_page first only for elements they don't cover. "
        parts.append("""
            Use only the reco MCP tools: call inspect_page, then record_page, then call render_status with its render_id until \
            the status is done or failed. \(change)If the result has warnings, fix those steps and record once more. Don't ask \
            questions; choose sensible steps yourself. When it's done, reply in one or two short sentences saying what the video \
            shows\(take == nil ? "" : " and what changed"), without paths or selectors. If it fails, reply with the error.
            """)
        return parts.joined(separator: "\n\n")
    }

    private static func line(_ message: AgentChatMessage) -> String {
        switch message.role {
        case .user: "User: \(message.text)"
        case .agent: "Agent: \(message.text)"
        case .failure: "Recording failed: \(message.text)"
        }
    }

    private static func json(_ steps: RecordPageRequest) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Encoding plain values can't fail
        return (try? encoder.encode(steps)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}
