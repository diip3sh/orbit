//
//  AgentToolError.swift
//  Reco
//

import Foundation

/// Why an agent's tool call failed. The messages are read by a model, so they say what to do next.
nonisolated enum AgentToolError: LocalizedError, Equatable {
    case invalidArgument(String)
    case busy(renderID: String)
    case unknownRender
    case exporting
    case unknownTool(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidArgument(let reason): reason
        case .busy(let renderID): "Reco is already rendering render_id \(renderID). Call render_status with it, then try again."
        case .unknownRender: "No render with that render_id. Only the latest render is kept; start one with record_page."
        case .exporting: "Reco is already exporting another recording. Call export_recording for that one until it is done, then try again."
        case .unknownTool(let name): "Unknown tool \(name). Use one of: \(AgentToolCatalog.tools.map(\.name).joined(separator: ", "))."
        case .timedOut: "The page didn't finish loading in time. Check the url and try again."
        }
    }
}
