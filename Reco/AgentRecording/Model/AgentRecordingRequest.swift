//
//  AgentRecordingRequest.swift
//  Reco
//

import Foundation

/// What the user asked a coding agent to record: from the Record with AI Agent panel (spec 0007),
/// or from the agent chat of a web take in the editor, to record it again with changes (spec 0008),
/// or of a motion video's window, to change it (spec 0011).
nonisolated struct AgentRecordingRequest: Equatable, Sendable {
    var url: URL
    var instructions: String
    var agent: AgentKind

    /// What the panel makes: a launch video (a motion video of the product's real UI) or a walkthrough.
    var mode = Mode.walkthrough

    nonisolated enum Mode: String, CaseIterable, Sendable {
        case launch
        case walkthrough
    }

    /// The model to use, or `nil` for the agent's own default.
    var model: String?

    /// The take the chat asks to change, or `nil` for a new one.
    var take: Take?

    /// The motion video the chat asks to change, or `nil`.
    var motion: MotionVideo?

    /// The conversation before these instructions, oldest first.
    var conversation: [AgentChatMessage] = []

    /// A motion video to change, and what the user has selected in its window: what "this" means.
    nonisolated struct MotionVideo: Equatable, Sendable {
        var bundle: URL
        var scene: String?
        var layer: String?
    }

    /// The file a chat's run is about: the take or the motion video.
    var subject: URL? {
        motion?.bundle ?? take?.movie
    }

    /// How long a run may take: a launch video's captures and checks come on top of the agent's turns.
    var timeLimit: Duration {
        mode == .launch && take == nil && motion == nil ? .seconds(20 * 60) : AgentRunOutcome.timeLimit
    }

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
        review names as its best features. The user may be signed in to the product in Reco: inspect its app too (/app, \
        /dashboard, or where Log in and Get started lead) and record that when it shows the product, before falling back to \
        the marketing pages. Don't record anything until you can say in one sentence what the product is for.
        2. Plan. Write a shot list of four to six beats that tell one story: what the product is (the hero), its two or three \
        strongest features, each on its own page or section, and the call to action. For each beat name the one element the \
        viewer should see (a product screenshot, a feature card, a short heading with its text), the page it is on and how to \
        get there: a click on the link that opens the page, a scroll to the section.
        3. Record with record_page, one or two steps per beat, every step with a show: the element the video zooms on; it zooms \
        on nothing else. Show the thing itself, not the heading above it; show the hero or a whole section to stay zoomed out. \
        Hover something in or beside what you show for 2 to 3 s, so it is in view. To open a page, click its link, then hover that \
        page's hero showing it. Never park the cursor on the navigation while a page loads. Use scale 2, which stays sharp when \
        the video zooms in, unless inspect_page's render_cost at 2 is over 8: then the render would take over 8 minutes a \
        minute, so use 1. Keep 1 s still at the start, 0.8 to 1 s between steps, and 45 to 60 s in all unless asked otherwise. \
        Hide the overlays inspect_page lists that aren't the product (a cookie banner, a chat button, an announcement bar), never \
        the navigation.
        """

    /// What a launch video shows when the user said nothing.
    static let defaultLaunchInstructions = "No instructions: a 20 to 40 s launch video of the product."

    /// What the video shows when the user said nothing, for this request's mode.
    var defaultInstructions: String {
        mode == .launch && take == nil ? Self.defaultLaunchInstructions : Self.defaultInstructions
    }

    /// How a launch video is made (spec 0011, *Agent*): doctrine, not quotas. It says what good looks
    /// like and forbids the tells; it never asks for a number of elements.
    static let launchPlaybook = """
        How to make it:
        1. Research. Call inspect_page on the page and on one or two pages its product or features navigation links to (each \
        call loads and measures a page: they're the slow part of research); if you have web search or fetch, read what the \
        product says about itself. Write the pitch in one sentence: what it is, for \
        whom, and what's new (the user's line first, if they gave one).
        2. Script. A hook over the product in the first 3 s, six words at most, never a logo intro. Then four to six beats from the \
        shot catalogue, each one idea: the product itself early (uiHero), its two or three strongest features shown on their real \
        UI (uiFocus with a region, featureSequence, uiCascade), and an endCard with the name or logo and the address or call to \
        action. At least half the time shows the product. 20 to 40 s in all. Copy is the product's own words, a few words a line: \
        no hype words (revolutionary, seamless, unlock, supercharge), no exclamation marks, no questions to the viewer.
        3. Style from inspect_page's brand: canvas background, style text, dim and accent, face. Pacing driftAndCut for calm, \
        precise products; beats for playful, fast ones. Seams: cut most of the time, zoomThrough or cutOnMotion where the motion \
        carries on, fade at most once.
        4. UI. Assets from inspect_page's liftable on the pages you inspected: product screenshots, app mockups and feature \
        cards, the largest that show the product; never a block of marketing text. Hide the page's overlays that cover them. \
        At most one live asset (with steps), and none where inspect_page's render_cost at 2 is over 4: a take renders the page \
        frame by frame, minutes on a heavy page. Write the whole video in one edit_motion call (a name, the style, the assets, \
        the scenes), then capture_ui; fix an asset it can't capture with set_asset, or drop it.
        5. Check. Call preview_motion and look at the picture: cut-off or overlapping text, an empty or wrong element, a frame \
        that says nothing. Fix it and every finding in one edit_motion call, then preview again; stop after two previews.
        6. Export with export_recording: the bundle, format h264, resolution 2160 (sharp 4K: the video is drawn, not scaled).
        """

    /// How a motion video is changed from its window's chat.
    static let motionChangePlaybook = """
        First call edit_motion on this bundle with no operations: it describes the video, its scenes, layer ids and moves. Then \
        change only what the user asks and keep everything else; set_moves replaces a layer's moves, so copy the ones you keep \
        from the reply. "Slower" \
        means about 1.5 times as long, "faster" about two thirds; frames are 1/frame_rate s. Then call preview_motion once to \
        check it. Don't export.
        """

    /// How a video is recorded again with a change (spec 0008).
    static let changePlaybook = """
        Record the whole video again with record_page, changing only what the user asks and keeping the other steps; reuse \
        their selectors, and call inspect_page first only for elements they don't cover.
        """

    /// The task for the agent. It starts with a word so a command line can't read it as a flag.
    var prompt: String {
        if let motion {
            return motionPrompt(motion)
        }
        if mode == .launch, take == nil {
            return launchPrompt
        }
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

    private var launchPrompt: String {
        let wanted = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "Make a launch video of this product with Reco: \(url.absoluteString)",
            "What the user said:\n" + (wanted.isEmpty ? Self.defaultLaunchInstructions : wanted),
            Self.launchPlaybook,
            """
            Use only the reco MCP tools (web search and fetch are for research). Don't ask questions; decide yourself. When it's \
            exported, reply in one or two short sentences with the pitch and what the video shows, without paths or selectors. \
            If it fails, reply with the error.
            """
        ].joined(separator: "\n\n")
    }

    private func motionPrompt(_ motion: MotionVideo) -> String {
        let wanted = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = ["Change this motion video with Reco's edit_motion tool: \(motion.bundle.path(percentEncoded: false))"]
        if let scene = motion.scene {
            let layer = motion.layer.map { ", layer \"\($0)\"" } ?? ""
            parts.append("The user has scene \"\(scene)\"\(layer) selected: \"this\" or \"it\" means that.")
        }
        if !conversation.isEmpty {
            parts.append("The conversation so far:\n" + conversation.map(Self.line).joined(separator: "\n"))
        }
        parts.append("What the user asks now:\n" + wanted)
        parts.append(Self.motionChangePlaybook)
        parts.append("""
            Use only the reco MCP tools. Don't ask questions; decide yourself. When it's done, reply in one or two short sentences \
            saying what changed, without paths. If it fails, reply with the error.
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
