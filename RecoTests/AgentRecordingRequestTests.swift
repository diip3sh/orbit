//
//  AgentRecordingRequestTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct AgentRecordingRequestTests {

    private func request(address: String = "apple.com/macbook-pro", instructions: String) throws -> AgentRecordingRequest {
        let url = try #require(WebScript.url(from: address))
        return AgentRecordingRequest(url: url, instructions: instructions, agent: .claudeCode, model: nil)
    }

    private func expected(url: String, wanted: String) -> String {
        """
        Record a video of this web page with Reco: \(url)

        What the video should show:
        \(wanted)

        Use only the reco MCP tools: call inspect_page, then record_page, then call render_status with its render_id until \
        the status is done or failed. Don't ask questions; choose sensible steps yourself. When it's done, reply with the \
        movie's path only. If it fails, reply with the error.
        """
    }

    @Test func thePromptNamesThePageAndWhatTheVideoShows() throws {
        let prompt = try request(instructions: "  Hover Buy, then scroll to the specs.\n").prompt

        #expect(prompt == expected(url: "https://apple.com/macbook-pro", wanted: "Hover Buy, then scroll to the specs."))
    }

    @Test func withoutInstructionsTheAgentChoosesTheCallToAction() throws {
        let prompt = try request(instructions: " \n ").prompt

        let wanted = "No instructions: hover and click the page's main call to action, then scroll through the page."
        #expect(prompt == expected(url: "https://apple.com/macbook-pro", wanted: wanted))
    }

    @Test func theAddressIsNormalizedAndTheLocalOnesStayPlain() throws {
        #expect(try request(address: "localhost:3000", instructions: "x").prompt.contains("this web page with Reco: http://localhost:3000\n"))
        #expect(try request(address: "  Example.com ", instructions: "x").prompt.contains("with Reco: https://Example.com\n"))
    }

    @Test func thePromptStartsWithAWordSoNoCommandLineReadsItAsAFlag() throws {
        #expect(try request(instructions: "--help").prompt.hasPrefix("Record"))
    }
}
