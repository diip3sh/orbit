//
//  AgentServerCommand.swift
//  Reco
//

/// How an agent starts Reco's MCP server: the app's own binary with ``AgentBridgeClient/argument``,
/// and the token in its environment.
nonisolated struct AgentServerCommand: Equatable, Sendable {
    var executable: String
    var token: String

    /// The server's name in every agent's settings; Reco only ever touches entries with this name.
    static let serverName = "reco"

    static let tokenVariable = "RECO_BRIDGE_TOKEN"
}
