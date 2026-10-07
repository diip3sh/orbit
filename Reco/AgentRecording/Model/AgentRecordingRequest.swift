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
    static let defaultInstructions = "A product walkthrough: what the product is, its two or three strongest features, and its call to action."

    /// What the agent does with its plan.
    private var finish: String {
        rendersVideo
            ? "Record it with record_page, then call render_status with its render_id until the status is done or failed."
            : "Put it on the timeline with record_page (its status is planned): Orbit renders it when you're done, and the user can change it and render again."
    }

    /// Re-recording on warnings stops after one try: on a page whose warning can't be fixed by
    /// recording again, an agent would otherwise record forever. ``AgentTools`` holds it to that.
    private static let warnings = "If the result has warnings, fix those steps and record once more, only once; then report what that result says."

    /// The task for the agent. It starts with a word so a command line can't read it as a flag.
    var prompt: String {
        let wanted = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if resuming != nil {
            let follow = rendersVideo ? ", and render_status until the status is done or failed" : ""
            return """
                Change the recording of \(url.absoluteString): \(wanted)

                Use only the reco tools: open_page, look, read_page, hover or click again if you need to see something, then \
                call record_page again with the changed steps, every hover, click and type with a show\(follow). \
                \(Self.warnings) Don't ask questions. When it's done, reply in one short sentence with what you changed. If it fails, \
                reply with the error.
                """
        }
        return """
            Record a walkthrough video of this website with Reco: \(url.absoluteString)

            What the video should show:
            \(wanted.isEmpty ? Self.defaultInstructions : wanted)

            1. Research. Don't record anything until you can say in one sentence what the product is for. open_page and \
            read_page the page, then the two to four product or feature pages its navigation links to (their href); look down \
            each one. If you can search the web, read the product's features page and what a review names as its best \
            features. Know what the product is and the three features that matter most, each with the page or section that \
            shows it best.
            2. Plan four to six beats that tell one story: what the product is (its hero, 3 to 5 s), its two or three strongest \
            features, each on its own page or section (6 to 10 s each), and the call to action (3 s). For each beat name the \
            one element the viewer should see (a product screenshot, a feature card, a short heading that is the message; not \
            a nav item, a decorative image or empty space) and how to get there: a click on the link that opens its page, or a \
            scroll to its section. Show the thing itself, not the heading above it; a hero or whole section is a beat without \
            zoom. Visit at least two feature pages or sections. Never park the cursor on the navigation while a page loads.
            3. Record one or two steps per beat, every hover, click and type with show set to its beat's element. Hover \
            something in or beside what you show for 2 to 3 s, so it's in view when the step starts. To open a page, click its \
            link, then hover that page's hero with show on it. Leave 0.8 to 1 s between steps, 1.5 to 3 s per hover, click or \
            scroll, 45 to 60 s in all. Use scale 1 unless asked for 2. Only use selectors you saw on the page they're on.
            \(finish) \(Self.warnings) Use only the reco tools, and web search or fetch if you have them, and don't ask \
            questions. When it's done, reply in one or two sentences saying what the video shows, without paths or selectors. \
            If it fails, reply with the error.
            """
    }
}
