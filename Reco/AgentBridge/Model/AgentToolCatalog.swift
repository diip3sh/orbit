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
        call render_status with its render_id until done. If the result has warnings, fix those steps and record again.
        """

    static let inspectPage = "inspect_page"
    static let recordPage = "record_page"
    static let renderStatus = "render_status"

    static let tools: [Definition] = [
        Definition(
            name: inspectPage,
            description: """
                Loads a web page in Reco and lists what it shows: size, title and its visible links, buttons, inputs and \
                headings, each with a CSS selector, role, text, box in page pixels at scroll 0, and a link's href. Reco scrolls \
                through the page first, so content that loads on the way is listed too. Call it before record_page to get \
                selectors to hover, click or scroll to, and on the page a click opens (its href) for the steps after that click.
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
                Records a web page as a demo video with a smooth cursor: Reco plays the steps (hover, click, scroll) on the live \
                page frame by frame into a movie with input telemetry, and opens it in its editor, which zooms in where the cursor \
                stops and clicks. Before each hover or click Reco scrolls its element into view if needed; a scroll to a selector \
                finds the element again as the page is then. Rendering can take longer than a minute: this returns when the movie \
                is done or after 45 s with status rendering and a render_id; then call render_status until it is done. One render \
                at a time. Pacing that reads well: about 1 s still first, 1.5 to 3 s per hover or click so viewers can read it, \
                0.8 to 1 s between steps for the cursor to travel, 1.5 to 3 s per scroll. A hover menu stays open while the cursor \
                is over it. A click that opens another page cuts to it. The result's warnings say which steps missed their element.
                """,
            schema: #"""
            {"type":"object","properties":{"url":{"type":"string","description":"Page address; https:// added if missing"},
            "viewport":{"type":"string","enum":["desktop","laptop","tablet","phone"],"default":"desktop"},
            "scale":{"type":"integer","enum":[1,2],"default":2},
            "duration":{"type":"number","description":"Seconds, max 120; default: last step end + 1.5"},
            "steps":{"type":"array","items":{"type":"object","properties":{
            "action":{"type":"string","enum":["hover","click","scroll"]},
            "selector":{"type":"string","description":"CSS selector from inspect_page; for scroll, the element to bring near the top"},
            "y":{"type":"number","description":"scroll only: page offset in CSS px"},
            "start":{"type":"number","description":"seconds; default: 0.8 s after the previous step, the first at 1 s"},
            "duration":{"type":"number","description":"seconds; default 1.5 (hover/click), 2 (scroll)"}},
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
