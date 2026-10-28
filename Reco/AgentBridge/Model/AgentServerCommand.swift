//
//  AgentServerCommand.swift
//  Reco
//

/// How an agent starts Reco's MCP server: the app's own binary with ``AgentBridgeClient/argument``,
/// and the token in its environment.
nonisolated struct AgentServerCommand: Equatable, Sendable {
    var executable: String
    var token: String

    /// The server's name in every agent's settings; Reco only ever touches entries with this name
    /// or ``legacyServerName``.
    static let serverName = "orbit"

    /// The name before the rebrand to Orbit. An agent still listing it shows as out of date, and
    /// connecting it again replaces that entry with ``serverName``.
    static let legacyServerName = "reco"

    static let tokenVariable = "RECO_BRIDGE_TOKEN"
}
