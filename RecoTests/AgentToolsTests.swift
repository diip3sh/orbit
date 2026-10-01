//
//  AgentToolsTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

@MainActor
struct AgentToolsTests {

    private func tools(onRendered: @escaping (URL) -> Void = { _ in }) -> AgentTools {
        AgentTools(settings: SettingsStore(), onRendered: onRendered)
    }

    private func status(_ reply: (text: String, isError: Bool)) throws -> RenderStatus {
        try JSONDecoder().decode(RenderStatus.self, from: Data(reply.text.utf8))
    }

    @Test func aPageThatCantBeLoadedFailsTheRenderWithAReason() async throws {
        var opened: [URL] = []
        let tools = tools { opened.append($0) }

        // Nothing listens on port 1, so the load is refused at once
        let reply = await tools.call("record_page", arguments: Data(##"{"url":"http://localhost:1","steps":[{"action":"hover","selector":"#a"}]}"##.utf8))

        let failed = try status(reply)
        #expect(reply.isError)
        #expect(failed.status == .failed)
        #expect(failed.error?.contains("couldn't be loaded") == true)
        #expect(failed.movie == nil)
        #expect(opened.isEmpty)
        #expect(tools.job == failed)
    }

    @Test func renderStatusReportsTheLatestRenderAndRefusesOthers() async throws {
        let tools = tools()
        let failed = try status(await tools.call("record_page", arguments: Data(#"{"url":"http://localhost:1","steps":[]}"#.utf8)))

        let known = await tools.call("render_status", arguments: Data(#"{"render_id":"\#(failed.renderID)"}"#.utf8))
        let unknown = await tools.call("render_status", arguments: Data(#"{"render_id":"other"}"#.utf8))

        #expect(try status(known) == failed)
        #expect(unknown.isError)
        #expect(unknown.text.contains("record_page"))
    }

    @Test func aFailedRenderDoesntBlockTheNextOne() async throws {
        let tools = tools()
        let first = try status(await tools.call("record_page", arguments: Data(#"{"url":"http://localhost:1","steps":[]}"#.utf8)))

        let second = try status(await tools.call("record_page", arguments: Data(#"{"url":"http://localhost:1","steps":[]}"#.utf8)))

        #expect(second.renderID != first.renderID)
        #expect(second.status == .failed)
    }

    @Test func badArgumentsAreErrorsTheAgentCanActOn() async {
        let tools = tools()

        let wrongType = await tools.call("record_page", arguments: Data(#"{"url":"example.com","steps":"click"}"#.utf8))
        let notJSON = await tools.call("inspect_page", arguments: Data("nope".utf8))
        let invalid = await tools.call("inspect_page", arguments: Data(#"{"url":"example.com","viewport":"watch"}"#.utf8))
        let unknown = await tools.call("format_disk", arguments: Data("{}".utf8))

        #expect(wrongType.isError && wrongType.text.contains("steps"))
        #expect(notJSON.isError)
        #expect(invalid.isError && invalid.text.contains("desktop"))
        #expect(unknown.isError && unknown.text.contains("inspect_page"))
        #expect(tools.job == nil)
    }
}
