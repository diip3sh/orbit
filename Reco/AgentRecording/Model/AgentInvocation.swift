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

    private static let policyFile = "reco-policy.toml"
    private static let claudeServersFile = "reco-mcp.json"
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
    /// Built from the catalog, so a new tool is allowed where the others are.
    private static var cursorPermissions: String {
        let allowed = AgentToolCatalog.names.map { "\"Mcp(reco:\($0))\"" }.joined(separator: ",")
        return #"{"permissions":{"allow":["# + allowed + #"],"deny":["Shell(*)","Write(**)","WebFetch(*)"]}}"#
    }

    /// OpenCode's permissions, merged over the user's: the last matching rule wins, and an MCP
    /// tool is `<server>_<tool>`.
    private static let openCodePermissions = #"{"permission":{"*":"deny","reco_*":"allow"}}"#

    /// An `mcpServers` file with Reco's server in `entry`'s format. Cursor's CLI drops its whole
    /// `~/.cursor/mcp.json` when one entry has a type it doesn't know (e.g. `"streamableHttp"`, which the
    /// editor accepts), but still reads the workspace's `.cursor/mcp.json`. Measured with cursor-agent
    /// 2026.09.26.
    private static func mcpServers(_ server: AgentServerCommand, entry kind: AgentKind) -> String {
        let servers = [AgentServerCommand.serverName: kind.jsonEntry(for: server)]
        let data = (try? JSONSerialization.data(withJSONObject: ["mcpServers": servers], options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Whether `kind`'s runs carry Reco's server themselves (see `make`), so an installed command line is
    /// enough and Settings → Agents needn't have connected it first
    static func bringsServer(for kind: AgentKind) -> Bool {
        kind == .claudeCode || kind == .cursor
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
        // Claude Code and Cursor share the flag for a follow-up (`AgentStreamEvent.streams`)
        let resume = request.resuming.map { ["--resume", $0] } ?? []
        var environment: [String: String] = [:]
        var files: [String: String] = [:]
        let arguments: [String]
        switch request.agent {
        case .claudeCode:
            // Reco's server comes with the run, so it works before (or without) Settings → Agents adds it to
            // the user's config; strict keeps the user's other servers from starting
            files[claudeServersFile] = mcpServers(server, entry: AgentKind.claudeCode)
            // --tools, --allowedTools and --mcp-config take any number of values, so the prompt goes right
            // after -p and each list ends at the next flag
            // stream-json (which needs --verbose) feeds the chat; the session is kept for a follow-up. Web search
            // and fetch, read-only, are the one other thing allowed: for learning what the product is
            arguments = ["-p", prompt, "--tools", "WebSearch,WebFetch", "--allowedTools", "mcp__reco__*", "WebSearch", "WebFetch",
                         "--permission-mode", "dontAsk",
                         "--mcp-config", directory.appending(path: claudeServersFile).path(percentEncoded: false),
                         "--strict-mcp-config"] + resume + option("--model") + ["--output-format", "stream-json", "--verbose"]
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
            files[cursorServersFile] = mcpServers(server, entry: AgentKind.cursor)
            arguments = ["-p", "--trust", "--approve-mcps", "--output-format", "stream-json"] + resume + option("--model") + [prompt]
        case .claudeDesktop:
            return nil
        }
        return AgentInvocation(executableName: name, arguments: arguments, environment: environment, files: files)
    }
}
