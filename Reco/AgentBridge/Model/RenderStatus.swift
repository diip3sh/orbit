//
//  RenderStatus.swift
//  Reco
//

/// How a render started by an agent is going, as `record_page` and `render_status` report it.
nonisolated struct RenderStatus: Codable, Equatable, Sendable {

    /// What the agent passes to `render_status`.
    var renderID: String
    var status: Status

    /// From 0 to 1.
    var progress: Double

    /// Paths of the finished movie and its telemetry sidecar.
    var movie: String?
    var telemetry: String?

    /// Selectors the page had no match for, so their cursor clips aim at the middle of the viewport.
    var unmatchedSelectors: [String]?

    /// What went wrong on the page during the take (``WebTakeIssues``), for the agent to fix.
    var warnings: [String]?
    var error: String?

    nonisolated enum Status: String, Codable, Sendable {
        case rendering
        case done
        case failed
    }

    private enum CodingKeys: String, CodingKey {
        case renderID = "render_id"
        case unmatchedSelectors = "unmatched_selectors"
        case status, progress, movie, telemetry, warnings, error
    }
}
