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
        the status is done or failed. If the result has warnings, fix those steps and record once more. Don't ask \
        questions; choose sensible steps yourself. When it's done, reply in one or two short sentences saying what the video \
        shows, without paths or selectors. If it fails, reply with the error.
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

    @Test func aChatRequestCarriesTheTakesStepsAndTheConversation() throws {
        var request = try request(instructions: "Slower, and click Buy at the end.")
        let steps = RecordPageRequest(url: "https://apple.com/macbook-pro", steps: [.init(action: "hover", selector: "#buy", start: 1, duration: 1.5)])
        request.take = .init(movie: URL(filePath: "/m/take.mov"), steps: steps)
        request.conversation = [
            AgentChatMessage(role: .user, text: "Hover Buy."),
            AgentChatMessage(role: .agent, text: "The video hovers Buy."),
            AgentChatMessage(role: .failure, text: "The page crashed.")
        ]

        let prompt = request.prompt

        #expect(prompt.hasPrefix("Record a video of this web page with Reco: https://apple.com/macbook-pro\n\n"))
        #expect(prompt.contains("""
            The current video was recorded with these record_page arguments:
            {"steps":[{"action":"hover","duration":1.5,"selector":"#buy","start":1}],"url":"https://apple.com/macbook-pro"}
            """))
        #expect(prompt.contains("The conversation so far:\nUser: Hover Buy.\nAgent: The video hovers Buy.\nRecording failed: The page crashed.\n\n"))
        #expect(prompt.contains("What the user asks now:\nSlower, and click Buy at the end.\n\n"))
        #expect(prompt.contains("Record the whole video again with record_page, changing only what the user asks"))
        #expect(prompt.contains("saying what the video shows and what changed"))
    }
}
