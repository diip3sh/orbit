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

        1. Research. Don't record anything until you can say in one sentence what the product is for. open_page and \
        read_page the page, then the two to four product or feature pages its navigation links to (their href); look down \
        each one. If you can search the web, read the product's features page and what a review names as its best \
        features. Know what the product is and the three features that matter most, each with the page or section that \
        shows it best.
        2. Plan four to six beats that tell one story: what the product is (its hero, 3 to 5 s), its two or three strongest \
        features, each on its own page or section (6 to 10 s each), and the call to action (3 s). For each beat name the \
        one element the viewer should see (a product screenshot, a feature card, a short heading that is the message; not \
        a nav item, a decorative image or empty space) and how to get there: a click on the link that opens its page, or a \
        scroll to its section. Show the thing itself, not the heading above it; a hero or whole section is a beat without \
        zoom. Visit at least two feature pages or sections. Never park the cursor on the navigation while a page loads.
        3. Record one or two steps per beat, every hover, click and type with show set to its beat's element. Hover \
        something in or beside what you show for 2 to 3 s, so it's in view when the step starts. To open a page, click its \
        link, then hover that page's hero with show on it. Leave 0.8 to 1 s between steps, 1.5 to 3 s per hover, click or \
        scroll, 45 to 60 s in all. Use scale 1 unless asked for 2. Only use selectors you saw on the page they're on.
        Record it with record_page, then call render_status with its render_id until the status is done or failed. If the \
        result has warnings, fix those steps and record once more, only once; then report what that result says. Use only \
        the reco tools, and web search or fetch if you have them, and don't ask questions. When it's done, reply in one or \
        two sentences saying what the video shows, without paths or selectors. If it fails, reply with the error.
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
