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
        Learn the site first, as a person browsing it would: open_page, then look further down the page, read_page for \
        its content, and hover or click into its menus, tabs and key pages, each step returning a screenshot. Then plan \
        a walkthrough and record_page it; if that returns status rendering, call render_status with its render_id until \
        done.
        """

    static let inspectPage = "inspect_page"
    static let recordPage = "record_page"
    static let renderStatus = "render_status"
    static let openPage = "open_page"
    static let look = "look"
    static let readPage = "read_page"
    static let click = "click"
    static let hover = "hover"
    static let type = "type"

    /// Every tool, for agents whose permissions list them one by one.
    static var names: [String] {
        tools.map(\.name)
    }

    static let tools: [Definition] = browsingTools + [
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
                Records a web page as a video with a smooth cursor: Reco plays the steps (hover, click, type, scroll) on the live page \
                frame by frame into a movie with input telemetry, and opens it in its editor for styling. Give the hovers and \
                clicks that matter a zoom (2 is a good default) so the camera moves in on them; a take without any zoom is \
                auto-zoomed on its clicks instead. type clicks an input and types its text into it letter by letter (search \
                boxes, sign-up forms); its duration defaults to the text's length. Rendering \
                can take longer than a minute: this returns when the movie is done or after 45 s with status rendering and a \
                render_id; then call render_status until it is done. From Reco's chat it returns status planned instead: the \
                steps are on the user's timeline and Reco renders them when you're done, so there is nothing to wait for. One render at a time. Steps are spaced automatically \
                (0.5 s apart) unless they give a start.
                """,
            schema: #"""
            {"type":"object","properties":{"url":{"type":"string","description":"Page address; https:// added if missing"},
            "viewport":{"type":"string","enum":["desktop","laptop","tablet","phone"],"default":"desktop"},
            "scale":{"type":"integer","enum":[1,2],"default":2},
            "duration":{"type":"number","description":"Seconds, max 120; default: last step end + 1"},
            "steps":{"type":"array","items":{"type":"object","properties":{
            "action":{"type":"string","enum":["hover","click","type","scroll"]},
            "selector":{"type":"string","description":"CSS selector from inspect_page; for scroll, the element to bring near the top"},
            "y":{"type":"number","description":"scroll only: page offset in CSS px"},
            "start":{"type":"number","description":"seconds; default: 0.5 s after the previous step"},
            "duration":{"type":"number","description":"seconds; default 1 (hover/click), 1.5 (scroll)"},
            "zoom":{"type":"number","minimum":1.25,"maximum":4,"description":"hover/click/type only: magnify the element by this factor around the step, e.g. 2"},
            "text":{"type":"string","maxLength":500,"description":"type only: what to type into the input"}},
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

    /// The browsing session (spec 0011): the Reco window's live page, which the user watches. Each
    /// step answers with JSON and a screenshot of the viewport after it.
    static let browsingTools: [Definition] = [
        Definition(
            name: openPage,
            description: """
                Opens a page in Reco's live browser (the user watches it in the Web Recording window) and returns a \
                screenshot plus the page's size, title and its visible links, buttons, inputs and headings, each with a CSS \
                selector, role, text and box in page pixels. Start here, then look, read_page, hover and click to learn the site.
                """,
            schema: #"""
            {"type":"object","properties":{"url":{"type":"string","description":"Page address; https:// added if missing"},
            "viewport":{"type":"string","enum":["desktop","laptop","tablet","phone"],"default":"desktop"}},
            "required":["url"],"additionalProperties":false}
            """#
        ),
        Definition(
            name: look,
            description: "Scrolls the live page to y (CSS pixels from the top) and returns a screenshot of what the viewport shows there.",
            schema: #"""
            {"type":"object","properties":{"y":{"type":"number","minimum":0}},"required":["y"],"additionalProperties":false}
            """#
        ),
        Definition(
            name: readPage,
            description: "Returns the live page's text as a reader sees it, with its headings and where each is (y), to learn what the page says.",
            schema: #"""
            {"type":"object","properties":{},"additionalProperties":false}
            """#
        ),
        Definition(
            name: hover,
            description: "Moves the pointer onto an element of the live page, opening hover menus and tooltips, and returns a screenshot.",
            schema: #"""
            {"type":"object","properties":{"selector":{"type":"string"}},"required":["selector"],"additionalProperties":false}
            """#
        ),
        Definition(
            name: click,
            description: """
                Clicks an element of the live page as a person would (menus, tabs, links, buttons) and returns a screenshot; \
                if it opened another page, the result has its url. Avoid buttons that buy, delete or send anything.
                """,
            schema: #"""
            {"type":"object","properties":{"selector":{"type":"string"}},"required":["selector"],"additionalProperties":false}
            """#
        ),
        Definition(
            name: type,
            description: "Clicks an input of the live page and types text into it, e.g. a search box, and returns a screenshot.",
            schema: #"""
            {"type":"object","properties":{"selector":{"type":"string"},"text":{"type":"string","maxLength":500}},
            "required":["selector","text"],"additionalProperties":false}
            """#
        )
    ]
}
