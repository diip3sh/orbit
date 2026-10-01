//
//  AgentJSONConfig.swift
//  Reco
//

import Foundation

/// Adds Reco's entry to an agent's JSON settings, and takes it out again, leaving everything else
/// as the agent wrote it, apart from key order and spacing: keys are sorted so the file is stable.
nonisolated enum AgentJSONConfig {

    nonisolated enum EditError: Error, Equatable {

        /// Not plain JSON, e.g. it has comments: rewriting it would lose them.
        case notPlainJSON

        /// The top level, or the servers under `key`, aren't objects.
        case unexpectedShape
    }

    private static let writing: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

    /// The settings with `entry` as the `reco` server under `key`. `data` is `nil` or empty for no
    /// settings yet.
    static func connecting(_ data: Data?, key: String, entry: [String: Any]) throws -> Data {
        var root = try object(in: data) ?? [:]
        var servers = try servers(in: root, key: key) ?? [:]
        servers[AgentServerCommand.serverName] = entry
        root[key] = servers
        return try JSONSerialization.data(withJSONObject: root, options: writing)
    }

    /// The settings without the `reco` server, or `nil` when it wasn't there.
    static func disconnecting(_ data: Data, key: String) throws -> Data? {
        var root = try object(in: data) ?? [:]
        guard var servers = try servers(in: root, key: key), servers.removeValue(forKey: AgentServerCommand.serverName) != nil else {
            return nil
        }
        root[key] = servers
        return try JSONSerialization.data(withJSONObject: root, options: writing)
    }

    /// The `reco` server's entry, or `nil` when there is none or the settings aren't plain JSON.
    static func entry(in data: Data, key: String) -> [String: Any]? {
        guard let root = try? object(in: data), let servers = try? servers(in: root, key: key) else { return nil }
        return servers[AgentServerCommand.serverName] as? [String: Any]
    }

    static func state(of data: Data, key: String, expected: [String: Any]) -> AgentConnectionState {
        guard let entry = entry(in: data, key: key) else { return .notConnected }
        return NSDictionary(dictionary: entry).isEqual(to: expected) ? .connected : .outdated
    }

    private static func object(in data: Data?) throws -> [String: Any]? {
        guard let data, !data.isEmpty else { return nil }
        guard let parsed = try? JSONSerialization.jsonObject(with: data) else { throw EditError.notPlainJSON }
        guard let root = parsed as? [String: Any] else { throw EditError.unexpectedShape }
        return root
    }

    private static func servers(in root: [String: Any], key: String) throws -> [String: Any]? {
        guard let value = root[key] else { return nil }
        guard let servers = value as? [String: Any] else { throw EditError.unexpectedShape }
        return servers
    }
}
