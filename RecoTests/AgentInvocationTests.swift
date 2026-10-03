//
//  AgentInvocationTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct AgentInvocationTests {

    private let directory = URL(filePath: "/Users/someone/Library/Application Support/com.diip3sh.Reco/AgentRun")

    private func request(_ agent: AgentKind, model: String? = nil) throws -> AgentRecordingRequest {
        let url = try #require(WebScript.url(from: "example.com"))
        return AgentRecordingRequest(url: url, instructions: "Scroll down.", agent: agent, model: model)
    }

    private let server = AgentServerCommand(executable: "/Applications/Reco.app/Contents/MacOS/Reco", token: "abc123")

    private func invocation(_ agent: AgentKind, model: String? = nil) throws -> AgentInvocation {
        try #require(AgentInvocation.make(for: request(agent, model: model), in: directory, server: server))
    }

    @Test func claudeCodeGetsThePromptRightAfterPAndRecosToolsPlusWebResearch() throws {
        let prompt = try request(.claudeCode).prompt
        let plain = try invocation(.claudeCode)
        let chosen = try invocation(.claudeCode, model: "opus")

        let servers = "/Users/someone/Library/Application Support/com.diip3sh.Reco/AgentRun/reco-mcp.json"
        let head: [String] = ["-p", prompt, "--tools", "WebSearch,WebFetch", "--allowedTools", "mcp__reco__*", "WebSearch", "WebFetch",
                              "--permission-mode", "dontAsk", "--no-session-persistence", "--mcp-config", servers, "--strict-mcp-config"]
        let expected: [String] = head + ["--output-format", "text"]
        let expectedWithModel: [String] = head + ["--model", "opus", "--output-format", "text"]
        #expect(plain.executableName == "claude")
        #expect(plain.arguments == expected)
        #expect(chosen.arguments == expectedWithModel)
        #expect(plain.arguments.prefix(2) == ["-p", prompt])
        #expect(plain.environment.isEmpty)
    }

    @Test func claudeCodeGetsRecosServerFromTheRunWhateverItsOwnSettingsSay() throws {
        let file = try #require(try invocation(.claudeCode).files["reco-mcp.json"])
        let object = try #require(JSONSerialization.jsonObject(with: Data(file.utf8)) as? [String: [String: [String: Any]]])
        let reco = try #require(object["mcpServers"]?["reco"])

        #expect(NSDictionary(dictionary: reco).isEqual(to: AgentKind.claudeCode.jsonEntry(for: server)))
        // The token is in the file, never on the command line
        #expect(try !invocation(.claudeCode).arguments.contains { $0.contains(server.token) })
        #expect(AgentKind.allCases.filter(AgentInvocation.bringsOwnServer) == [.claudeCode, .cursor])
    }

    @Test func codexRunsReadOnlyAndApprovesRecosToolsInOneArgument() throws {
        let prompt = try request(.codex).prompt
        let plain = try invocation(.codex)
        let chosen = try invocation(.codex, model: "gpt-6-astra")

        let head: [String] = ["exec", "--skip-git-repo-check", "--ephemeral", "--sandbox", "read-only",
                              "-c", #"mcp_servers.reco.default_tools_approval_mode="approve""#]
        let expected: [String] = head + [prompt]
        let expectedWithModel: [String] = head + ["-m", "gpt-6-astra", prompt]
        #expect(plain.executableName == "codex")
        #expect(plain.arguments == expected)
        #expect(chosen.arguments == expectedWithModel)
    }

    @Test func openCodeDeniesEverythingButRecosToolsThroughItsEnvironment() throws {
        let prompt = try request(.openCode).prompt
        let plain = try invocation(.openCode)
        let chosen = try invocation(.openCode, model: "anthropic/claude-sonnet")

        let expected: [String] = ["run", prompt]
        let expectedWithModel: [String] = ["run", "-m", "anthropic/claude-sonnet", prompt]
        #expect(plain.executableName == "opencode")
        #expect(plain.arguments == expected)
        #expect(chosen.arguments == expectedWithModel)
        #expect(plain.environment == ["OPENCODE_CONFIG_CONTENT": #"{"permission":{"*":"deny","reco_*":"allow"}}"#])
    }

    @Test func geminiReadsAPolicyFileThatAllowsOnlyRecosServer() throws {
        let prompt = try request(.gemini).prompt
        let plain = try invocation(.gemini)
        let chosen = try invocation(.gemini, model: "gemini-3-flash-preview")

        let policy = "/Users/someone/Library/Application Support/com.diip3sh.Reco/AgentRun/reco-policy.toml"
        let head: [String] = ["--skip-trust", "--allowed-mcp-server-names", "reco", "--policy", policy, "-o", "text"]
        let expected: [String] = head + ["-p", prompt]
        let expectedWithModel: [String] = head + ["-m", "gemini-3-flash-preview", "-p", prompt]
        #expect(plain.executableName == "gemini")
        #expect(plain.arguments == expected)
        #expect(chosen.arguments == expectedWithModel)
        let file = try #require(plain.files["reco-policy.toml"])
        #expect(file.contains(#"toolName = "*""#) && file.contains(#"decision = "deny""#))
        #expect(file.contains(#"mcpName = "reco""#) && file.contains(#"decision = "allow""#))
        #expect(file.contains("priority = 100") && file.contains("priority = 200"))
    }

    @Test func grokAllowsOnlyRecosToolsAndNoWebOrSubagents() throws {
        let prompt = try request(.grok).prompt
        let plain = try invocation(.grok)
        let chosen = try invocation(.grok, model: "grok-4.6")

        let head: [String] = ["-p", prompt, "--permission-mode", "dontAsk", "--allow", "MCPTool(reco__*)", "--disable-web-search",
                              "--no-subagents", "--output-format", "plain"]
        let expectedWithModel: [String] = head + ["-m", "grok-4.6"]
        #expect(plain.executableName == "grok")
        #expect(plain.arguments == head)
        #expect(chosen.arguments == expectedWithModel)
    }

    @Test func cursorGetsAWorkspaceFileThatAllowsOnlyRecosThreeTools() throws {
        let prompt = try request(.cursor).prompt
        let plain = try invocation(.cursor)
        let chosen = try invocation(.cursor, model: "sonnet-4-thinking")

        let head: [String] = ["-p", "--trust", "--approve-mcps", "--output-format", "text"]
        let expected: [String] = head + [prompt]
        let expectedWithModel: [String] = head + ["--model", "sonnet-4-thinking", prompt]
        #expect(plain.executableName == "cursor-agent")
        #expect(plain.arguments == expected)
        #expect(chosen.arguments == expectedWithModel)
        let file = try #require(plain.files[".cursor/cli.json"])
        let object = try #require(JSONSerialization.jsonObject(with: Data(file.utf8)) as? [String: [String: [String]]])
        #expect(object["permissions"]?["allow"] == ["Mcp(reco:inspect_page)", "Mcp(reco:record_page)", "Mcp(reco:render_status)"])
        #expect(object["permissions"]?["deny"] == ["Shell(*)", "Write(**)", "WebFetch(*)"])
    }

    @Test func cursorGetsRecosServerInItsWorkspaceSoABrokenGlobalConfigDoesntHideIt() throws {
        let file = try #require(try invocation(.cursor).files[".cursor/mcp.json"])
        let object = try #require(JSONSerialization.jsonObject(with: Data(file.utf8)) as? [String: [String: [String: Any]]])
        let reco = try #require(object["mcpServers"]?["reco"])

        #expect(NSDictionary(dictionary: reco).isEqual(to: AgentKind.cursor.jsonEntry(for: server)))
        #expect(try invocation(.claudeCode).files[".cursor/mcp.json"] == nil)
    }

    @Test func claudeDesktopHasNoCommandLine() throws {
        #expect(AgentInvocation.executableName(for: .claudeDesktop) == nil)
        #expect(try AgentInvocation.make(for: request(.claudeDesktop), in: directory, server: server) == nil)
        for kind in AgentKind.allCases where kind != .claudeDesktop {
            #expect(AgentInvocation.executableName(for: kind) != nil)
        }
    }
}
