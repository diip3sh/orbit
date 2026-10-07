//
//  AgentInvocation.swift
//  Reco
//

import Foundation

/// The command line that runs one agent headlessly on a request, with only Reco's tools allowed
/// (spec 0007). All argument building is here, so a CLI changing a flag is a change to one function.
nonisolated struct AgentInvocation: Equatable, Sendable {

    /// The executable's name, looked up on the login shell's `PATH`.
    var executableName: String
    var arguments: [String]

    /// Variables to add to the login shell's environment.
    var environment: [String: String]

    /// Files the run needs, by path relative to its working directory.
    var files: [String: String]

    /// The agents that can run from the panel; Claude Desktop has no command line.
    static func executableName(for kind: AgentKind) -> String? {
        switch kind {
        case .claudeCode: "claude"
        case .codex: "codex"
        case .openCode: "opencode"
        case .gemini: "gemini"
        case .grok: "grok"
        case .cursor: "cursor-agent"
        case .claudeDesktop: nil
        }
    }

    /// Whether the run gives the agent Reco's server itself, so it works without Settings → Agents
    /// connecting it, whatever the agent's own settings say (e.g. Claude Code with `CLAUDE_CONFIG_DIR`
    /// set reads another file than the one Reco connects).
    static func bringsOwnServer(_ kind: AgentKind) -> Bool {
        kind == .claudeCode || kind == .cursor
    }

    private static let serversFile = "reco-mcp.json"
    private static let policyFile = "reco-policy.toml"
    private static let cursorFile = ".cursor/cli.json"
    private static let cursorServersFile = ".cursor/mcp.json"

    /// Denies every tool but the reco server's. Gemini reads a higher priority first.
    private static let geminiPolicy = """
        [[rule]]
        toolName = "*"
        decision = "deny"
        priority = 100

        [[rule]]
        mcpName = "reco"
        decision = "allow"
        priority = 200

        """

    /// The workspace permissions Cursor reads: the three Reco tools, no shell, writes or fetches.
    private static let cursorPermissions = """
        {"permissions":{"allow":["Mcp(reco:inspect_page)","Mcp(reco:record_page)","Mcp(reco:render_status)"],\
        "deny":["Shell(*)","Write(**)","WebFetch(*)"]}}
        """

    /// OpenCode's permissions, merged over the user's: the last matching rule wins, and an MCP
    /// tool is `<server>_<tool>`.
    private static let openCodePermissions = #"{"permission":{"*":"deny","reco_*":"allow"}}"#

    /// Reco's server as `kind` lists it in an `mcpServers` file. Cursor's CLI drops its whole
    /// `~/.cursor/mcp.json` when one entry has a type it doesn't know (e.g. `"streamableHttp"`, which
    /// the editor accepts), but still reads the workspace's `.cursor/mcp.json`. Measured with
    /// cursor-agent 2026.09.26.
    private static func servers(_ server: AgentServerCommand, for kind: AgentKind) -> String {
        let servers = [AgentServerCommand.serverName: kind.jsonEntry(for: server)]
        let data = (try? JSONSerialization.data(withJSONObject: ["mcpServers": servers], options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// The command for `request`, run in `directory` and reaching Reco through `server`; `nil` when
    /// its agent can't run headlessly.
    static func make(for request: AgentRecordingRequest, in directory: URL, server: AgentServerCommand) -> AgentInvocation? {
        guard let name = executableName(for: request.agent) else { return nil }
        let prompt = request.prompt
        let model = request.model.map { [$0] } ?? []
        func option(_ flag: String) -> [String] {
            model.isEmpty ? [] : [flag] + model
        }
        var environment: [String: String] = [:]
        var files: [String: String] = [:]
        let arguments: [String]
        switch request.agent {
        case .claudeCode:
            // --tools and --allowedTools take any number of values, so the prompt goes right after -p.
            // Reco's server from a file in the run's folder, not the command line, which other users see
            files[serversFile] = servers(server, for: .claudeCode)
            arguments = ["-p", prompt, "--tools", "", "--allowedTools", "mcp__reco__*", "--permission-mode", "dontAsk",
                         "--no-session-persistence", "--mcp-config", directory.appending(path: serversFile).path(percentEncoded: false),
                         "--strict-mcp-config"] + option("--model") + ["--output-format", "text"]
        case .codex:
            arguments = ["exec", "--skip-git-repo-check", "--ephemeral", "--sandbox", "read-only",
                         "-c", #"mcp_servers.reco.default_tools_approval_mode="approve""#] + option("-m") + [prompt]
        case .openCode:
            environment["OPENCODE_CONFIG_CONTENT"] = openCodePermissions
            arguments = ["run"] + option("-m") + [prompt]
        case .gemini:
            files[policyFile] = geminiPolicy
            arguments = ["--skip-trust", "--allowed-mcp-server-names", "reco",
                         "--policy", directory.appending(path: policyFile).path(percentEncoded: false),
                         "-o", "text"] + option("-m") + ["-p", prompt]
        case .grok:
            arguments = ["-p", prompt, "--permission-mode", "dontAsk", "--allow", "MCPTool(reco__*)", "--disable-web-search",
                         "--no-subagents", "--output-format", "plain"] + option("-m")
        case .cursor:
            files[cursorFile] = cursorPermissions
            files[cursorServersFile] = servers(server, for: .cursor)
            arguments = ["-p", "--trust", "--approve-mcps", "--output-format", "text"] + option("--model") + [prompt]
        case .claudeDesktop:
            return nil
        }
        return AgentInvocation(executableName: name, arguments: arguments, environment: environment, files: files)
    }
}
