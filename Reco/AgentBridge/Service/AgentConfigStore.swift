//
//  AgentConfigStore.swift
//  Reco
//

import Darwin
import Foundation

/// Reads and edits the agents' own settings files to add Reco as an MCP server, and remove it again
/// (spec 0006). Only the `reco` entry is touched, and only for an agent that's installed. File
/// contents are never logged: they hold other servers' secrets.
@MainActor
struct AgentConfigStore {

    nonisolated enum StoreError: LocalizedError, Equatable {
        case translocated
        case notInstalled(String)
        case symbolicLink(String)

        var errorDescription: String? {
            switch self {
            case .translocated: "Move Reco to Applications first, then connect the agent."
            case .notInstalled(let agent): "\(agent) isn't installed."
            case .symbolicLink(let path): "\(path) is a symbolic link, which Reco doesn't rewrite. Add the server to it yourself."
            }
        }
    }

    var home = URL.userHome
    var command = AgentServerCommand(
        executable: Bundle.main.executableURL?.path(percentEncoded: false) ?? CommandLine.arguments[0],
        token: AgentBridgeServer.token()
    )
    var bundlePath = Bundle.main.bundlePath

    private var exists: (URL) -> Bool {
        { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
    }

    func state(of kind: AgentKind) -> AgentConnectionState {
        guard kind.isInstalled(home: home, exists: exists) else { return .notInstalled }
        guard let data = try? Data(contentsOf: kind.configURL(home: home)) else { return .notConnected }
        switch kind.format {
        case .json(let key): return AgentJSONConfig.state(of: data, key: key, expected: kind.jsonEntry(for: command))
        case .toml: return AgentTOMLConfig.state(of: String(data: data, encoding: .utf8) ?? "", expected: command)
        }
    }

    /// Adds Reco to the agent's settings, or brings its entry up to date.
    func connect(_ kind: AgentKind) throws {
        // A copy run from a quarantined download lives at a random path that changes on every launch
        guard !bundlePath.contains("/AppTranslocation/") else { throw StoreError.translocated }
        guard kind.isInstalled(home: home, exists: exists) else { throw StoreError.notInstalled(kind.displayName) }
        let url = kind.configURL(home: home)
        let existing = exists(url) ? try Data(contentsOf: url) : nil
        let updated: Data
        switch kind.format {
        case .json(let key):
            updated = try AgentJSONConfig.connecting(existing, key: key, entry: kind.jsonEntry(for: command))
        case .toml:
            let text = try AgentTOMLConfig.connecting(existing.flatMap { String(data: $0, encoding: .utf8) }, command: command)
            updated = Data(text.utf8)
        }
        try replace(url, with: updated)
    }

    /// Removes Reco from the agent's settings, leaving every other entry; nothing to do when it isn't there.
    func disconnect(_ kind: AgentKind) throws {
        let url = kind.configURL(home: home)
        guard exists(url) else { return }
        let data = try Data(contentsOf: url)
        let updated: Data?
        switch kind.format {
        case .json(let key):
            updated = try AgentJSONConfig.disconnecting(data, key: key)
        case .toml:
            updated = AgentTOMLConfig.disconnecting(String(data: data, encoding: .utf8) ?? "").map { Data($0.utf8) }
        }
        if let updated {
            try replace(url, with: updated)
        }
    }

    /// Writes `data` as the file at `url` in one step, so an agent running meanwhile never reads half
    /// of it, keeping the file's permissions (0600 for a new one: it holds the token).
    private func replace(_ url: URL, with data: Data) throws {
        let path = url.path(percentEncoded: false)
        if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            throw StoreError.symbolicLink(path)
        }
        // Next to the target, so the rename stays on one volume
        let temporary = url.deletingLastPathComponent().appending(path: ".\(url.lastPathComponent).reco-\(UUID().uuidString)")
        let temporaryPath = temporary.path(percentEncoded: false)
        try data.write(to: temporary)
        do {
            let permissions = (try? FileManager.default.attributesOfItem(atPath: path))?[.posixPermissions] ?? 0o600
            try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: temporaryPath)
            guard Darwin.rename(temporaryPath, path) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }
}
