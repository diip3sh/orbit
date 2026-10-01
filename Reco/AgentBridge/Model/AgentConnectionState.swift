//
//  AgentConnectionState.swift
//  Reco
//

/// Whether an agent's settings list Reco.
nonisolated enum AgentConnectionState: Equatable, Sendable {
    case notInstalled
    case notConnected
    case connected

    /// Reco's entry is there but differs from what Reco would write now, e.g. the app moved.
    case outdated
}
