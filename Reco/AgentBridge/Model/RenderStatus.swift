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

    /// What went wrong on the page, one message per step and problem, each with its time
    /// (``WebTakeIssues``): from the take when it rendered, else from the page the plan was aimed at.
    var warnings: [String]?
    var error: String?

    nonisolated enum Status: String, Codable, Sendable {
        case rendering
        /// On the Web Recording window's timeline, for the user to render.
        case planned
        case done
        case failed
    }

    private enum CodingKeys: String, CodingKey {
        case renderID = "render_id"
        case status, progress, movie, telemetry, warnings, error
    }
}
