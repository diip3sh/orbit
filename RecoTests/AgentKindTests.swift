//
//  AgentKindTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct AgentKindTests {

    private let home = URL(filePath: "/Users/someone")

    @Test func configsAreUnderTheGivenHome() {
        #expect(AgentKind.claudeCode.configURL(home: home).path() == "/Users/someone/.claude.json")
        #expect(AgentKind.codex.configURL(home: home).path() == "/Users/someone/.codex/config.toml")
        #expect(AgentKind.claudeDesktop.configURL(home: home).path(percentEncoded: false)
            == "/Users/someone/Library/Application Support/Claude/claude_desktop_config.json")
    }

    @Test func installedMeansItsFileOrFolderExists() {
        let codex = AgentKind.codex
        #expect(codex.isInstalled(home: home) { $0.lastPathComponent == "config.toml" })
        #expect(codex.isInstalled(home: home) { $0.lastPathComponent == ".codex" })
        #expect(!codex.isInstalled(home: home) { _ in false })
        // Claude Code has only the file
        #expect(AgentKind.claudeCode.isInstalled(home: home) { $0.lastPathComponent == ".claude.json" })
        #expect(!AgentKind.claudeCode.isInstalled(home: home) { $0.lastPathComponent == ".claude" })
    }

    @Test func formatsFollowEachAgent() {
        #expect(AgentKind.codex.format == .toml)
        #expect(AgentKind.grok.format == .toml)
        #expect(AgentKind.openCode.format == .json(key: "mcp"))
        #expect(AgentKind.claudeCode.format == .json(key: "mcpServers"))
    }
}
