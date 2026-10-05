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

    /// The agent's conversation this follows up on, from the chat (spec 0008); `nil` starts one.
    var resuming: String?

    /// Whether the agent renders the video, or only puts its steps on the Web Recording window's timeline
    /// for the user to play, change and render (the chat, spec 0008).
    var rendersVideo = true

    /// What the chat shows for this request: the user's words, or what the agent will do without any.
    var summary: String {
        let wanted = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        return wanted.isEmpty ? "Record \(url.host() ?? url.absoluteString)" : wanted
    }

    /// What the video shows when the user said nothing.
    static let defaultInstructions = "A walkthrough of the site: its hero, each main section, the key interactions (menus, tabs, search) and the pricing or main call to action."

    /// What the agent does with its plan.
    private var finish: String {
        rendersVideo
            ? "Record it with record_page, then call render_status with its render_id until the status is done or failed."
            : "Put it on the timeline with record_page (its status is planned): Orbit renders it when you're done, and the user can change it and render again."
    }

    /// The task for the agent. It starts with a word so a command line can't read it as a flag.
    var prompt: String {
        let wanted = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if resuming != nil {
            return """
                Change the recording of \(url.absoluteString): \(wanted)

                Use only the reco tools: open_page, look, read_page, hover or click again if you need to see something, then \
                call record_page again with the changed steps\(rendersVideo ? " and render_status until the status is done or failed" : ""). \
                Don't ask questions. When it's done, reply in one short sentence with what you changed. If it fails, reply with the error.
                """
        }
        return """
            Record a walkthrough video of this website with Reco: \(url.absoluteString)

            What the video should show:
            \(wanted.isEmpty ? Self.defaultInstructions : wanted)

            Get to know the site before filming it, as a person would: open_page, then look further down (look with y) \
            until you've seen every section, read_page for what it says, and hover or click its menus, tabs and important \
            links to see what they show. Then plan the walkthrough: each important part in order, hovering and clicking what \
            a viewer should notice, typing into a search box or input when that shows the product, scrolling between \
            sections, and zoom (zoom: 2) on the steps that matter. Aim for 20 to 60 seconds. Only plan steps you tried and saw \
            work, on selectors that matched, and keep the cursor's path off menus it shouldn't open. \(finish) Use only the reco \
            tools and don't ask questions. When it's done, reply in one short sentence with what the video shows. If it fails, \
            reply with the error.
            """
    }
}
