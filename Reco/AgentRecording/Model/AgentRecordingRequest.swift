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

    /// How a video is made from nothing: learn the product, plan the story, then record it. The
    /// editor zooms where the cursor stops, so the steps say where to stop and for how long.
    static let playbook = """
        How to make it:
        1. Research. Call inspect_page on the page, then on the two to four pages its product or features navigation links \
        to (use their href), to learn what the product does and which features it shows best.
        2. Plan. Write a shot list of four to six beats that tell one story: what the product is (its hero), its two or three \
        strongest features, each on its own page or section, and the call to action at the end. For each beat decide the one \
        thing the viewer should see and how to get there: a click on the link that opens the page, a scroll to the section.
        3. Record with record_page. The video zooms in wherever the cursor stops, so stop it only on what the viewer should \
        read: hover the feature's heading or the thing itself for 2 to 3 s, hover a menu to open it, click a link to open its \
        page and then hover that page's heading. Never park the cursor on empty space or on the navigation while a page \
        loads. Keep 1 s still at the start, 0.8 to 1 s between steps, and 45 to 60 s in all unless asked otherwise.
        """

    /// How a video is recorded again with a change (spec 0008).
    static let changePlaybook = """
        Record the whole video again with record_page, changing only what the user asks and keeping the other steps; reuse \
        their selectors, and call inspect_page first only for elements they don't cover.
        """

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
        parts.append(take == nil ? Self.playbook : Self.changePlaybook)
        parts.append("""
            Use only the reco MCP tools; render_status with the render_id until the status is done or failed. Don't ask questions; \
            decide yourself. If the result has warnings, fix those steps and record once more, but only once: then stop and report, \
            whatever the second result says. When it's done, reply in one or two short sentences saying what the video \
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
