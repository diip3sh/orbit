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
    case unknownTool(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidArgument(let reason): reason
        case .busy(let renderID): "Reco is already rendering render_id \(renderID). Call render_status with it, then try again."
        case .unknownRender: "No render with that render_id. Only the latest render is kept; start one with record_page."
        case .unknownTool(let name): "Unknown tool \(name). Use inspect_page, record_page or render_status."
        case .timedOut: "The page didn't finish loading in time. Check the url and try again."
        }
    }
}
