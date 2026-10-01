//
//  AgentTOMLConfigTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct AgentTOMLConfigTests {

    private let command = AgentServerCommand(executable: "/Applications/Reco.app/Contents/MacOS/Reco", token: "secret")

    private var table: String {
        """
        [mcp_servers.reco]
        command = "/Applications/Reco.app/Contents/MacOS/Reco"
        args = ["--mcp"]
        env = { RECO_BRIDGE_TOKEN = "secret" }
        """
    }

    @Test func tableIsExactlyWhatCodexReads() {
        #expect(AgentTOMLConfig.table(for: command) == table)
    }

    @Test func connectingToNothingWritesTheTable() throws {
        #expect(try AgentTOMLConfig.connecting(nil, command: command) == table + "\n")
        #expect(try AgentTOMLConfig.connecting("", command: command) == table + "\n")
    }

    @Test func appendingKeepsOtherTablesByteForByte() throws {
        let original = "model = \"gpt\"\n\n[mcp_servers.other]\ncommand = \"x\"\n# note"

        let result = try AgentTOMLConfig.connecting(original, command: command)

        #expect(result == original + "\n\n" + table + "\n")
        #expect(AgentTOMLConfig.disconnecting(result) == original + "\n")
    }

    @Test func connectingThenDisconnectingRestoresAFileThatEndsInANewline() throws {
        let original = "model = \"gpt\"\n\n[profiles.fast]\neffort = \"low\"\n"

        let connected = try AgentTOMLConfig.connecting(original, command: command)

        #expect(connected == original + "\n" + table + "\n")
        #expect(AgentTOMLConfig.disconnecting(connected) == original)
    }

    @Test func reconnectingReplacesOurTableWhereItIs() throws {
        let stale = "[mcp_servers.reco]\ncommand = \"/old/Reco\"\nargs = [\"--mcp\"]\n\n[mcp_servers.reco.env]\nRECO_BRIDGE_TOKEN = \"old\"\n"
        let original = "[a]\nx = 1\n\n" + stale + "\n# the next one\n[b]\ny = 2\n"

        let result = try AgentTOMLConfig.connecting(original, command: command)

        #expect(result == "[a]\nx = 1\n\n" + table + "\n\n# the next one\n[b]\ny = 2\n")
    }

    @Test func disconnectingRemovesTheTableAndItsSubTablesOnly() throws {
        let original = """
            [mcp_servers.other]
            command = "x"

            [mcp_servers.reco]
            command = "y"

            [mcp_servers.reco.env]
            A = "1"

            [mcp_servers.recorder]
            command = "z"
            """

        let result = try #require(AgentTOMLConfig.disconnecting(original))

        #expect(result == "[mcp_servers.other]\ncommand = \"x\"\n\n[mcp_servers.recorder]\ncommand = \"z\"")
        #expect(AgentTOMLConfig.removing(original).removed == "[mcp_servers.reco]\ncommand = \"y\"\n\n[mcp_servers.reco.env]\nA = \"1\"")
    }

    @Test func disconnectingNeedsNothingWhenRecoIsNotThere() {
        #expect(AgentTOMLConfig.disconnecting("[mcp_servers.other]\ncommand = \"x\"\n") == nil)
    }

    @Test func otherSpellingsOfRecoAreRefused() {
        let forms = [
            "mcp_servers.reco.command = \"x\"\n",
            "mcp_servers.reco = { command = \"x\" }\n",
            "[mcp_servers]\nreco = { command = \"x\" }\n",
            "[mcp_servers]\nreco.command = \"x\"\n",
            "mcp_servers = { reco = { command = \"x\" } }\n"
        ]
        for form in forms {
            #expect(throws: AgentTOMLConfig.EditError.unrecognisedEntry) {
                try AgentTOMLConfig.connecting(form, command: command)
            }
        }
    }

    @Test func quotedHeadersAreOurTableToo() throws {
        let result = try AgentTOMLConfig.connecting("[mcp_servers.\"reco\"]\ncommand = \"x\"\n", command: command)

        #expect(result == table + "\n")
    }

    @Test func similarNamesAreNotRefused() throws {
        let original = "[mcp_servers]\nrecorder = 1\n"

        #expect(try AgentTOMLConfig.connecting(original, command: command) == original + "\n" + table + "\n")
    }

    @Test func quotingEscapesWhatBasicStringsNeed() {
        #expect(AgentTOMLConfig.quoted(#"C:\a "b""#) == #""C:\\a \"b\"""#)
        #expect(AgentTOMLConfig.quoted("a\nb\t\u{1}") == #""a\nb\t\u0001""#)
        #expect(AgentTOMLConfig.quoted("/Users/émile/Reco") == "\"/Users/émile/Reco\"")
    }

    @Test func stateTellsConnectedFromOutdatedFromNeither() {
        #expect(AgentTOMLConfig.state(of: "[a]\nx = 1\n\n" + table + "\n", expected: command) == .connected)
        #expect(AgentTOMLConfig.state(of: table.replacing("secret", with: "old"), expected: command) == .outdated)
        #expect(AgentTOMLConfig.state(of: "[a]\nx = 1\n", expected: command) == .notConnected)
    }
}
