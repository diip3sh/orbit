//
//  AgentJSONConfigTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct AgentJSONConfigTests {

    private let command = AgentServerCommand(executable: "/Applications/Reco.app/Contents/MacOS/Reco", token: "secret")

    private var entry: [String: Any] { AgentKind.cursor.jsonEntry(for: command) }

    private func parse(_ data: Data?) throws -> NSDictionary {
        let data = try #require(data)
        return try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    private func json(_ text: String) -> Data {
        Data(text.utf8)
    }

    @Test func connectingToNothingMakesTheServersObject() throws {
        for data in [nil, Data()] {
            let result = try parse(AgentJSONConfig.connecting(data, key: "mcpServers", entry: entry))
            #expect(result == ["mcpServers": ["reco": entry]] as NSDictionary)
        }
    }

    @Test func connectingKeepsEverythingElse() throws {
        let original = json(#"{"theme":"dark","nested":{"a":[1,2,{"b":null}]},"mcpServers":{"other":{"command":"x","args":["--y"]}}}"#)

        let result = try parse(AgentJSONConfig.connecting(original, key: "mcpServers", entry: entry))

        let expected = try parse(original).mutableCopy() as? NSMutableDictionary
        let servers = try #require((expected?["mcpServers"] as? NSDictionary)?.mutableCopy() as? NSMutableDictionary)
        servers["reco"] = entry
        expected?["mcpServers"] = servers
        #expect(result == expected)
    }

    @Test func connectingReplacesAnExistingEntry() throws {
        let original = json(#"{"mcpServers":{"reco":{"command":"/old/Reco","args":["--mcp"]},"other":{"command":"x"}}}"#)

        let result = try AgentJSONConfig.connecting(original, key: "mcpServers", entry: entry)

        #expect(try parse(result) == ["mcpServers": ["reco": entry, "other": ["command": "x"]]] as NSDictionary)
    }

    @Test func outputIsPrettyAndSortedWithoutEscapedSlashes() throws {
        let result = try AgentJSONConfig.connecting(nil, key: "mcpServers", entry: ["command": "/a/b", "args": ["--mcp"]])

        let text = try #require(String(data: result, encoding: .utf8))
        #expect(text.contains("\"/a/b\""))
        #expect(text.contains("\n"))
        let args = try #require(text.firstRange(of: "args"))
        let command = try #require(text.firstRange(of: "command"))
        #expect(args.lowerBound < command.lowerBound)
    }

    @Test func entryShapesFollowEachAgentsFormat() {
        let environment = ["RECO_BRIDGE_TOKEN": "secret"]
        let executable = command.executable
        #expect(NSDictionary(dictionary: AgentKind.claudeCode.jsonEntry(for: command))
            == ["type": "stdio", "command": executable, "args": ["--mcp"], "env": environment] as NSDictionary)
        #expect(NSDictionary(dictionary: AgentKind.openCode.jsonEntry(for: command))
            == ["type": "local", "command": [executable, "--mcp"], "environment": environment, "enabled": true] as NSDictionary)
        #expect(NSDictionary(dictionary: AgentKind.gemini.jsonEntry(for: command))
            == ["command": executable, "args": ["--mcp"], "env": environment] as NSDictionary)
    }

    @Test func openCodeKeepsItsServersUnderMcp() throws {
        let result = try parse(AgentJSONConfig.connecting(json(#"{"$schema":"x","mcp":{}}"#), key: "mcp", entry: AgentKind.openCode.jsonEntry(for: command)))

        #expect(result["$schema"] as? String == "x")
        #expect((result["mcp"] as? NSDictionary)?["reco"] != nil)
    }

    @Test func disconnectingRemovesOnlyReco() throws {
        let original = json(#"{"keep":1,"mcpServers":{"reco":{"command":"x"},"other":{"command":"y"}}}"#)

        let result = try parse(AgentJSONConfig.disconnecting(original, key: "mcpServers"))

        #expect(result == ["keep": 1, "mcpServers": ["other": ["command": "y"]]] as NSDictionary)
    }

    @Test func disconnectingNeedsNothingWhenRecoIsNotThere() throws {
        #expect(try AgentJSONConfig.disconnecting(json(#"{"mcpServers":{"other":{}}}"#), key: "mcpServers") == nil)
        #expect(try AgentJSONConfig.disconnecting(json("{}"), key: "mcpServers") == nil)
    }

    @Test func commentsAreNeverRewritten() {
        // Foundation reads a trailing comma as plain JSON, and writing it out again loses nothing
        for text in ["{ // my servers\n \"mcpServers\": {} }", "{ /* mine */ \"mcpServers\": {} }", "not json"] {
            #expect(throws: AgentJSONConfig.EditError.notPlainJSON) {
                try AgentJSONConfig.connecting(json(text), key: "mcpServers", entry: entry)
            }
            #expect(throws: AgentJSONConfig.EditError.notPlainJSON) {
                try AgentJSONConfig.disconnecting(json(text), key: "mcpServers")
            }
        }
    }

    @Test func otherShapesAreRefused() {
        for text in ["[]", #"{"mcpServers":[]}"#, #"{"mcpServers":"x"}"#] {
            #expect(throws: AgentJSONConfig.EditError.unexpectedShape) {
                try AgentJSONConfig.connecting(json(text), key: "mcpServers", entry: entry)
            }
        }
    }

    @Test func stateTellsConnectedFromOutdatedFromNeither() {
        let connected = json(#"{"mcpServers":{"reco":{"command":"/Applications/Reco.app/Contents/MacOS/Reco","args":["--mcp"],"env":{"RECO_BRIDGE_TOKEN":"secret"}}}}"#)
        let moved = json(#"{"mcpServers":{"reco":{"command":"/old/Reco","args":["--mcp"],"env":{"RECO_BRIDGE_TOKEN":"secret"}}}}"#)

        #expect(AgentJSONConfig.state(of: connected, key: "mcpServers", expected: entry) == .connected)
        #expect(AgentJSONConfig.state(of: moved, key: "mcpServers", expected: entry) == .outdated)
        #expect(AgentJSONConfig.state(of: json(#"{"mcpServers":{}}"#), key: "mcpServers", expected: entry) == .notConnected)
        #expect(AgentJSONConfig.state(of: json("{ // no"), key: "mcpServers", expected: entry) == .notConnected)
    }
}
