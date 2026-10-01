//
//  AgentConfigStoreTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

@MainActor
struct AgentConfigStoreTests {

    private let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    private let command = AgentServerCommand(executable: "/Applications/Reco.app/Contents/MacOS/Reco", token: "secret")

    private func store(bundlePath: String = "/Applications/Reco.app") -> AgentConfigStore {
        AgentConfigStore(home: home, command: command, bundlePath: bundlePath)
    }

    private func write(_ text: String, to path: String, permissions: Int = 0o644) throws {
        let url = home.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path(percentEncoded: false))
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOf: home.appending(path: path), encoding: .utf8)
    }

    @Test func anAgentWithoutItsFileOrFolderIsNotInstalledAndNothingIsCreated() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)

        for kind in AgentKind.allCases {
            #expect(store().state(of: kind) == .notInstalled)
            #expect(throws: AgentConfigStore.StoreError.notInstalled(kind.displayName)) { try store().connect(kind) }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: home.path(percentEncoded: false)).isEmpty)
    }

    @Test func connectingAddsTheEntryAndKeepsTheRest() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try write(#"{"theme":"dark","mcpServers":{"other":{"command":"x"}}}"#, to: ".cursor/mcp.json")

        #expect(store().state(of: .cursor) == .notConnected)
        try store().connect(.cursor)

        #expect(store().state(of: .cursor) == .connected)
        let object = try #require(JSONSerialization.jsonObject(with: Data(read(".cursor/mcp.json").utf8)) as? [String: Any])
        #expect(object["theme"] as? String == "dark")
        let servers = try #require(object["mcpServers"] as? [String: Any])
        #expect(Set(servers.keys) == ["other", "reco"])
    }

    @Test func connectingCreatesTheFileInAnInstalledAgentsFolder() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home.appending(path: ".codex"), withIntermediateDirectories: true)

        #expect(store().state(of: .codex) == .notConnected)
        try store().connect(.codex)

        #expect(try read(".codex/config.toml") == AgentTOMLConfig.table(for: command) + "\n")
        #expect(store().state(of: .codex) == .connected)
        let permissions = try FileManager.default.attributesOfItem(atPath: home.appending(path: ".codex/config.toml").path(percentEncoded: false))[.posixPermissions] as? Int
        #expect(permissions == 0o600)
    }

    @Test func aMovedAppIsOutdatedUntilReconnected() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try write(#"{"mcpServers":{"reco":{"command":"/old/Reco","args":["--mcp"]}}}"#, to: ".gemini/settings.json")

        #expect(store().state(of: .gemini) == .outdated)
        try store().connect(.gemini)

        #expect(store().state(of: .gemini) == .connected)
    }

    @Test func disconnectingKeepsOtherServersAndPermissions() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try write("model = \"gpt\"\n\n[mcp_servers.other]\ncommand = \"x\"\n", to: ".codex/config.toml", permissions: 0o640)
        try store().connect(.codex)

        try store().disconnect(.codex)

        #expect(try read(".codex/config.toml") == "model = \"gpt\"\n\n[mcp_servers.other]\ncommand = \"x\"\n")
        #expect(store().state(of: .codex) == .notConnected)
        let permissions = try FileManager.default.attributesOfItem(atPath: home.appending(path: ".codex/config.toml").path(percentEncoded: false))[.posixPermissions] as? Int
        #expect(permissions == 0o640)
    }

    @Test func disconnectingWhenNotConnectedChangesNothing() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let text = #"{"mcpServers":{"other":{"command":"x"}}}"#
        try write(text, to: ".cursor/mcp.json")

        try store().disconnect(.cursor)
        try store().disconnect(.codex)

        #expect(try read(".cursor/mcp.json") == text)
    }

    @Test func aFileWithCommentsIsLeftAlone() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let text = "{\n  // my servers\n  \"mcp\": {}\n}\n"
        try write(text, to: ".config/opencode/opencode.json")

        #expect(throws: AgentJSONConfig.EditError.notPlainJSON) { try store().connect(.openCode) }

        #expect(try read(".config/opencode/opencode.json") == text)
    }

    @Test func aSymbolicLinkIsNotReplaced() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try write("{}", to: "dotfiles/claude.json")
        try FileManager.default.createSymbolicLink(at: home.appending(path: ".claude.json"), withDestinationURL: home.appending(path: "dotfiles/claude.json"))

        #expect(throws: AgentConfigStore.StoreError.self) { try store().connect(.claudeCode) }

        #expect(try read("dotfiles/claude.json") == "{}")
    }

    @Test func aTranslocatedAppCantBeConnected() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try write("{}", to: ".cursor/mcp.json")

        #expect(throws: AgentConfigStore.StoreError.translocated) {
            try store(bundlePath: "/private/var/folders/x/AppTranslocation/ABC/d/Reco.app").connect(.cursor)
        }
        #expect(try read(".cursor/mcp.json") == "{}")
    }
}
