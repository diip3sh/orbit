//
//  AgentRecordedTakeTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct AgentRecordedTakeTests {

    private func request(instructions: String, take: URL? = nil) throws -> AgentRecordingRequest {
        var request = AgentRecordingRequest(url: try #require(URL(string: "https://example.com")), instructions: instructions, agent: .claudeCode)
        request.take = take.map { .init(movie: $0, steps: RecordPageRequest(url: "https://example.com", steps: [])) }
        request.conversation = [AgentChatMessage(role: .user, text: "Hover Buy."), AgentChatMessage(role: .agent, text: "Done.")]
        return request
    }

    @Test func theConversationGainsTheRequestAndTheAgentsReply() throws {
        let previous = URL(filePath: "/m/a.mov")

        let take = AgentRecordedTake(
            movie: URL(filePath: "/m/b.mov"), request: try request(instructions: " Slower. ", take: previous),
            output: "\u{1B}[1mThe video now hovers Buy for 3 s.\u{1B}[0m\n"
        )

        #expect(take.movie.path() == "/m/b.mov")
        #expect(take.replacing == previous)
        #expect(take.conversation.map(\.role) == [.user, .agent, .user, .agent])
        #expect(take.conversation.suffix(2).map(\.text) == ["Slower.", "The video now hovers Buy for 3 s."])
    }

    @Test func aSilentAgentOrNoInstructionsStillReadWell() throws {
        let take = AgentRecordedTake(movie: URL(filePath: "/m/b.mov"), request: try request(instructions: ""), output: "  \n")

        #expect(take.replacing == nil)
        #expect(take.conversation.suffix(2).map(\.text) == [AgentRecordingRequest.defaultInstructions, "Recorded."])
    }

    @Test func aLongReplyIsCut() throws {
        let take = AgentRecordedTake(movie: URL(filePath: "/m/b.mov"), request: try request(instructions: "x"), output: String(repeating: "a", count: 5000))

        #expect(take.conversation.last?.text.count == AgentRecordedTake.maximumReply)
    }
}
