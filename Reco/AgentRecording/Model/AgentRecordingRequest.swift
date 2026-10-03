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

    /// How a video is made from nothing: learn the product, plan the story, then record it, saying
    /// with each step what the video zooms on (``WebTakeZooms``).
    static let playbook = """
        How to make it:
        1. Research. Learn what the product does and which three features matter most. Call inspect_page on the page, then on \
        the two to four pages its product or features navigation links to (use their href): their descriptions and headings \
        say what each page shows. If you have web search or fetch, read the product's features or docs page too, and what a \
        review names as its best features. Don't record anything until you can say in one sentence what the product is for.
        2. Plan. Write a shot list of four to six beats that tell one story: what the product is (the hero), its two or three \
        strongest features, each on its own page or section, and the call to action. For each beat name the one element the \
        viewer should see (a product screenshot, a feature card, a short heading with its text), the page it is on and how to \
        get there: a click on the link that opens the page, a scroll to the section.
        3. Record with record_page, one or two steps per beat, every step with a show: the element the video zooms on; it zooms \
        on nothing else. Show the thing itself, not the heading above it; show the hero or a whole section to stay zoomed out. \
        Hover something in or beside what you show for 2 to 3 s, so it is in view. To open a page, click its link, then hover that \
        page's hero showing it. Never park the cursor on the navigation while a page loads. Use scale 1 unless asked for 2: a \
        minute at 2 takes over 15 minutes to render on a heavy page. Keep 1 s still at the start, 0.8 to 1 s between steps, and \
        45 to 60 s in all unless asked otherwise.
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
            Record only with the reco MCP tools (web search and fetch are for research); render_status with the render_id until the status is done or failed. Don't ask questions; \
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
