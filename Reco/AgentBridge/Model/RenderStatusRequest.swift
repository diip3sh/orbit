//
//  RenderStatusRequest.swift
//  Reco
//

/// The arguments of the `render_status` tool.
nonisolated struct RenderStatusRequest: Decodable, Sendable {
    var renderID: String

    private enum CodingKeys: String, CodingKey {
        case renderID = "render_id"
    }
}
