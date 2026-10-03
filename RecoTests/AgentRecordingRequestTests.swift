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
        Record a walkthrough video of this website with Reco: \(url)

        What the video should show:
        \(wanted)

        Get to know the site before filming it, as a person would: open_page, then look further down (look with y) \
        until you've seen every section, read_page for what it says, and hover or click its menus, tabs and important \
        links to see what they show. Then plan the walkthrough: each important part in order, hovering and clicking what \
        a viewer should notice, typing into a search box or input when that shows the product, scrolling between \
        sections, and zoom (zoom: 2) on the steps that matter. Aim for 20 to 60 seconds. Only plan steps you tried and saw \
        work, on selectors that matched, and keep the cursor's path off menus it shouldn't open. Record it with \
        record_page, then call render_status with its render_id until the status is done or failed. Use only the reco \
        tools and don't ask questions. When it's done, reply in one short sentence with what the video shows. If it fails, \
        reply with the error.
        """
    }

    @Test func thePromptNamesThePageAndWhatTheVideoShows() throws {
        let prompt = try request(instructions: "  Hover Buy, then scroll to the specs.\n").prompt

        #expect(prompt == expected(url: "https://apple.com/macbook-pro", wanted: "Hover Buy, then scroll to the specs."))
    }

    @Test func withoutInstructionsTheAgentChoosesTheCallToAction() throws {
        let prompt = try request(instructions: " \n ").prompt

        let wanted = AgentRecordingRequest.defaultInstructions
        #expect(prompt == expected(url: "https://apple.com/macbook-pro", wanted: wanted))
    }

    @Test func theAddressIsNormalizedAndTheLocalOnesStayPlain() throws {
        #expect(try request(address: "localhost:3000", instructions: "x").prompt.contains("this website with Reco: http://localhost:3000\n"))
        #expect(try request(address: "  Example.com ", instructions: "x").prompt.contains("with Reco: https://Example.com\n"))
    }

    @Test func thePromptStartsWithAWordSoNoCommandLineReadsItAsAFlag() throws {
        #expect(try request(instructions: "--help").prompt.hasPrefix("Record"))
        var followUp = try request(instructions: "--help")
        followUp.resuming = "session"
        #expect(followUp.prompt.hasPrefix("Change"))
    }

    @Test func aFollowUpAsksToRecordAgainWithTheChange() throws {
        var followUp = try request(instructions: " Make the scroll slower. ")
        followUp.resuming = "session"

        #expect(followUp.prompt.hasPrefix("Change the recording of https://apple.com/macbook-pro: Make the scroll slower.\n"))
        #expect(followUp.prompt.contains("call record_page again"))
    }

    @Test func fromTheChatThePlanGoesOnTheTimelineInsteadOfRendering() throws {
        var chat = try request(instructions: "x")
        chat.rendersVideo = false
        #expect(chat.prompt.contains("its status is planned"))
        #expect(!chat.prompt.contains("render_status"))
        chat.resuming = "session"
        #expect(!chat.prompt.contains("render_status"))
    }
}
