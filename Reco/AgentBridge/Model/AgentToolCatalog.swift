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
        call render_status with its render_id until done. If the result has warnings, fix those steps and record again. \
        For a finished file (MP4 or GIF) call export_recording with the movie. For a product walkthrough, inspect the pages \
        the navigation links to first, plan the beats (hero, two or three features on their own pages, the call to action), \
        then record: the video zooms wherever the cursor stops, so stop it only on what the viewer should read.
        """

    static let inspectPage = "inspect_page"
    static let recordPage = "record_page"
    static let renderStatus = "render_status"
    static let exportRecording = "export_recording"

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
                Records a web page as a demo video with a smooth cursor: Reco plays the steps (hover, click, type, scroll) on the live \
                page frame by frame into a movie with input telemetry, and opens it in its editor, which zooms in where the cursor \
                stops and clicks. Before each hover or click Reco scrolls its element into view if needed; a scroll to a selector \
                finds the element again as the page is then. Rendering can take longer than a minute: this returns when the movie \
                is done or after 45 s with status rendering and a render_id; then call render_status until it is done. One render \
                at a time. Pacing that reads well: about 1 s still first, 1.5 to 3 s per hover or click so viewers can read it, \
                0.8 to 1 s between steps for the cursor to travel, 1.5 to 3 s per scroll. A hover menu stays open while the cursor \
                is over it. A type step clicks its field, then types the text key by key (12 a second); end the text with \\n to press Enter, \
                which submits the field's form. A click that opens another page cuts to it. The result's warnings say which steps missed their element.
                """,
            schema: #"""
            {"type":"object","properties":{"url":{"type":"string","description":"Page address; https:// added if missing"},
            "viewport":{"type":"string","enum":["desktop","laptop","tablet","phone"],"default":"desktop"},
            "scale":{"type":"integer","enum":[1,2],"default":2},
            "duration":{"type":"number","description":"Seconds, max 120; default: last step end + 1.5"},
            "steps":{"type":"array","items":{"type":"object","properties":{
            "action":{"type":"string","enum":["hover","click","type","scroll"]},
            "selector":{"type":"string","description":"CSS selector from inspect_page; for scroll, the element to bring near the top"},
            "y":{"type":"number","description":"scroll only: page offset in CSS px"},
            "start":{"type":"number","description":"seconds; default: 0.8 s after the previous step, the first at 1 s"},
            "duration":{"type":"number","description":"seconds; default 1.5 (hover/click), 2 (scroll), the typing plus 1.1 (type)"},
            "text":{"type":"string","description":"type only: what to type into the selector's field"}},
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
        ),
        Definition(
            name: exportRecording,
            description: """
                Exports a recording as a finished video with Reco's edit: the zooms, the drawn cursor, click highlights and the \
                background, as its editor shows it. Saved next to the movie as <name>-edited. Use gif for READMEs, pull requests \
                and chats (silent, loops, 540 px at 25 fps unless set), hevc for a small MP4, h264 for an MP4 that plays \
                everywhere. Returns when the file is written or after 45 s with status exporting; then call it again with the \
                same arguments until done. One export at a time.
                """,
            schema: #"""
            {"type":"object","properties":{"movie":{"type":"string","description":"Path of the movie, from record_page or render_status"},
            "format":{"type":"string","enum":["hevc","h264","gif","prores422","prores4444"],"default":"hevc"},
            "resolution":{"type":"integer","description":"Shorter side in px, smaller than the recording's: 2160, 1440, 1080 or 720; gif: 720, 540 or 360"},
            "frame_rate":{"type":"integer","description":"Lower than the recording's: 60, 30 or 24; gif: 50 or 25"}},
            "required":["movie"],"additionalProperties":false}
            """#
        )
    ]
}
