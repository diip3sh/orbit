//
//  InspectPageRequest.swift
//  Reco
//

import Foundation

/// The arguments of the `inspect_page` tool.
nonisolated struct InspectPageRequest: Codable, Equatable, Sendable {
    var url: String
    var viewport: String?

    /// Elements whose boxes to return as `boxes`: the parts of a panel a motion video frames.
    var selectors: [String]?

    /// A script for the page at the requested viewport, or why there is none.
    func validated() throws(AgentToolError) -> WebScript {
        var script = WebScript()
        script.url = try RecordPageRequest.pageURL(url)
        script.viewport = try RecordPageRequest.viewportSize(viewport)
        return script
    }
}
