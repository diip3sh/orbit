//
//  AgentKind.swift
//  Reco
//

import Foundation

/// A coding agent whose MCP settings Reco can add itself to. Paths are relative to the user's real
/// home (spec 0006).
nonisolated enum AgentKind: String, CaseIterable, Identifiable, Sendable {
    case claudeCode
    case codex
    case openCode
    case cursor
    case gemini
    case claudeDesktop
    case grok

    var id: String { rawValue }

    /// How the agent's settings file is edited.
    enum Format: Equatable, Sendable {

        /// A JSON object with the servers under `key`.
        case json(key: String)
        case toml
    }

    var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .openCode: "OpenCode"
        case .cursor: "Cursor"
        case .gemini: "Gemini CLI"
        case .claudeDesktop: "Claude Desktop"
        case .grok: "Grok Build"
        }
    }

    /// The settings file that lists MCP servers.
    var configPath: String {
        switch self {
        case .claudeCode: ".claude.json"
        case .codex: ".codex/config.toml"
        case .openCode: ".config/opencode/opencode.json"
        case .cursor: ".cursor/mcp.json"
        case .gemini: ".gemini/settings.json"
        case .claudeDesktop: "Library/Application Support/Claude/claude_desktop_config.json"
        case .grok: ".grok/config.toml"
        }
    }

    /// The folder the agent keeps its settings in, which exists once it has been installed. `nil`
    /// for Claude Code, whose file sits in the home folder itself.
    var directoryPath: String? {
        switch self {
        case .claudeCode: nil
        case .codex: ".codex"
        case .openCode: ".config/opencode"
        case .cursor: ".cursor"
        case .gemini: ".gemini"
        case .claudeDesktop: "Library/Application Support/Claude"
        case .grok: ".grok"
        }
    }

    var format: Format {
        switch self {
        case .codex, .grok: .toml
        case .openCode: .json(key: "mcp")
        case .claudeCode, .cursor, .gemini, .claudeDesktop: .json(key: "mcpServers")
        }
    }

    func configURL(home: URL) -> URL {
        home.appending(path: configPath)
    }

    /// Whether the agent has been installed: its settings file or folder exists.
    func isInstalled(home: URL, exists: (URL) -> Bool) -> Bool {
        exists(configURL(home: home)) || directoryPath.map { exists(home.appending(path: $0)) } ?? false
    }

    /// The server's entry in a JSON settings file.
    func jsonEntry(for command: AgentServerCommand) -> [String: Any] {
        let environment = [AgentServerCommand.tokenVariable: command.token]
        switch self {
        case .openCode:
            return ["type": "local", "command": [command.executable, AgentBridgeClient.argument], "environment": environment, "enabled": true]
        case .claudeCode:
            return ["type": "stdio", "command": command.executable, "args": [AgentBridgeClient.argument], "env": environment]
        case .cursor, .gemini, .claudeDesktop, .codex, .grok:
            return ["command": command.executable, "args": [AgentBridgeClient.argument], "env": environment]
        }
    }
}
