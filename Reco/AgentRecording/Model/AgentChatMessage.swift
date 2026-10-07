//
//  AgentChatMessage.swift
//  Reco
//

import Foundation

/// One message of the conversation with an agent about a web take (spec 0008): what the user asked,
/// what the agent replied once it had recorded, or why a run failed.
nonisolated struct AgentChatMessage: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var role: Role
    var text: String

    nonisolated enum Role: String, Codable, Sendable {
        case user
        case agent
        case failure
    }
}
