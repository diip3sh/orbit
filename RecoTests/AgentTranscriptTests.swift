//
//  AgentTranscriptTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct AgentTranscriptTests {

    private func input(_ json: String) -> Data {
        Data(json.utf8)
    }

    @Test func aRunReadsAsRequestToolsAndReply() {
        var transcript = AgentTranscript()
        transcript.addRequest("Hover Pricing")
        transcript.apply(.session("s1"), from: .claudeCode)
        transcript.apply(.toolStarted(id: "1", tool: "inspect_page", input: input(#"{"url":"https://buildonto.dev"}"#)), from: .claudeCode)
        transcript.apply(.toolFinished(id: "1", isError: false), from: .claudeCode)
        transcript.apply(.toolStarted(id: "2", tool: "record_page", input: input(#"{"steps":[{},{},{}]}"#)), from: .claudeCode)
        transcript.apply(.toolFinished(id: "2", isError: true), from: .claudeCode)
        transcript.apply(.text("Recorded the pricing hover."), from: .claudeCode)

        #expect(transcript.entries.map(\.text) == ["Hover Pricing", "Looking at buildonto.dev", "Planning 3 steps", "Recorded the pricing hover."])
        #expect(transcript.entries.map(\.kind) == [.request, .tool(.done), .tool(.failed), .reply])
        #expect(transcript.lastReply == "Recorded the pricing hover.")
        #expect(transcript.sessionID(for: .claudeCode) == "s1")
        #expect(transcript.sessionID(for: .cursor) == nil)
    }

    @Test func consecutiveToolStepsShareOneGroup() {
        var transcript = AgentTranscript()
        transcript.addRequest("Hover Pricing")
        transcript.apply(.toolStarted(id: "1", tool: "inspect_page", input: input("{}")), from: .claudeCode)
        transcript.apply(.toolStarted(id: "2", tool: "record_page", input: input("{}")), from: .claudeCode)
        transcript.apply(.text("Done."), from: .claudeCode)
        transcript.apply(.toolStarted(id: "3", tool: "render_status", input: input("{}")), from: .claudeCode)

        let groups = transcript.groups
        #expect(groups.count == 4)
        guard case .request = groups[0], case .tools(let first) = groups[1], case .reply = groups[2], case .tools(let last) = groups[3] else {
            Issue.record("unexpected grouping \(groups)")
            return
        }
        #expect(first.map(\.id) == ["1", "2"])
        #expect(last.map(\.id) == ["3"])
        #expect(groups[1].id == "1")
        #expect(AgentTranscript().groups.isEmpty)
    }

    @Test func checkingTheRenderAgainUpdatesOneRow() {
        var transcript = AgentTranscript()
        for id in ["a", "b", "c"] {
            transcript.apply(.toolStarted(id: id, tool: "render_status", input: input("{}")), from: .cursor)
            transcript.apply(.toolFinished(id: id, isError: false), from: .cursor)
        }

        #expect(transcript.entries.count == 1)
        #expect(transcript.entries.first?.kind == .tool(.done))
    }

    @Test func theEndStopsAnySpinner() {
        var transcript = AgentTranscript()
        transcript.apply(.toolStarted(id: "1", tool: "inspect_page", input: input("{}")), from: .claudeCode)
        transcript.apply(.finished(isError: true), from: .claudeCode)

        #expect(transcript.entries.first?.kind == .tool(.done))
        #expect(transcript.entries.first?.text == "Looking at the page")
    }

    @Test func oneStepIsSingular() {
        #expect(AgentTranscript.describe(tool: "record_page", input: input(#"{"steps":[{}]}"#)) == "Planning 1 step")
    }

    @Test func browsingStepsReadAsWhatAPersonDoes() {
        func describe(_ tool: String, _ json: String) -> String {
            AgentTranscript.describe(tool: tool, input: Data(json.utf8))
        }
        #expect(describe("open_page", #"{"url":"buildonto.dev"}"#) == "Opening buildonto.dev")
        #expect(describe("look", #"{"y":1800}"#) == "Looking further down")
        #expect(describe("look", #"{"y":0}"#) == "Looking at the top")
        #expect(describe("read_page", "{}") == "Reading the page")
        #expect(describe("click", #"{"selector":"nav > a.pricing"}"#) == "Clicking a.pricing")
        #expect(describe("hover", ##"{"selector":"#menu"}"##) == "Hovering over #menu")
        #expect(describe("type", ##"{"selector":"#q","text":"maps"}"##) == "Typing “maps”")
    }
}

