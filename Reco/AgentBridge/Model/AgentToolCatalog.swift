//
//  AgentToolCatalog.swift
//  Reco
//

/// The tools Reco offers agents over MCP (spec 0006). Schemas are JSON text, parsed once by the
/// server: a Swift literal of nested values is slow to type check.
nonisolated enum AgentToolCatalog {

    nonisolated struct Definition: Sendable {
        var name: String
        var description: String

        /// The input's JSON schema, as JSON text.
        var schema: String
    }

    static let instructions = """
        Call inspect_page to get selectors, then record_page; if it returns status rendering, \
        call render_status with its render_id until done.
        """

    static let inspectPage = "inspect_page"
    static let recordPage = "record_page"
    static let renderStatus = "render_status"

    static let tools: [Definition] = [
        Definition(
            name: inspectPage,
            description: """
                Loads a web page in Reco and lists what it shows: size, title and its visible links, buttons, inputs and \
                headings, each with a CSS selector, role, text and box in page pixels at scroll 0. Call it before record_page \
                to get selectors to hover, click or scroll to.
                """,
            schema: #"""
            {"type":"object","properties":{"url":{"type":"string","description":"Page address; https:// added if missing"},
            "viewport":{"type":"string","enum":["desktop","laptop","tablet","phone"],"default":"desktop"}},
            "required":["url"],"additionalProperties":false}
            """#
        ),
        Definition(
            name: recordPage,
            description: """
                Records a web page as a video with a smooth cursor: Reco plays the steps (hover, click, scroll) on the live page \
                frame by frame into a movie with input telemetry, and opens it in its editor for auto-zoom and styling. Rendering \
                can take longer than a minute: this returns when the movie is done or after 45 s with status rendering and a \
                render_id; then call render_status until it is done. One render at a time. Steps are spaced automatically \
                (0.5 s apart) unless they give a start.
                """,
            schema: #"""
            {"type":"object","properties":{"url":{"type":"string","description":"Page address; https:// added if missing"},
            "viewport":{"type":"string","enum":["desktop","laptop","tablet","phone"],"default":"desktop"},
            "scale":{"type":"integer","enum":[1,2],"default":2},
            "duration":{"type":"number","description":"Seconds, max 120; default: last step end + 1"},
            "steps":{"type":"array","items":{"type":"object","properties":{
            "action":{"type":"string","enum":["hover","click","scroll"]},
            "selector":{"type":"string","description":"CSS selector from inspect_page; for scroll, the element to bring near the top"},
            "y":{"type":"number","description":"scroll only: page offset in CSS px"},
            "start":{"type":"number","description":"seconds; default: 0.5 s after the previous step"},
            "duration":{"type":"number","description":"seconds; default 1 (hover/click), 1.5 (scroll)"}},
            "required":["action"],"additionalProperties":false}}},"required":["url","steps"],"additionalProperties":false}
            """#
        ),
        Definition(
            name: renderStatus,
            description: """
                Waits up to 45 s for a render started by record_page, then reports its status and progress, and the movie and \
                telemetry paths when done. Only the latest render is kept.
                """,
            schema: #"""
            {"type":"object","properties":{"render_id":{"type":"string"}},"required":["render_id"],"additionalProperties":false}
            """#
        )
    ]
}
