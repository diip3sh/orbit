//
//  AgentStreamEventTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

/// Lines cut down from real runs on 2026-10-02: Claude Code with `--output-format stream-json --verbose`
/// and cursor-agent 2026.09.10 with `--output-format stream-json`, both inspecting example.com.
struct AgentStreamEventTests {

    private func events(_ line: String, _ agent: AgentKind) -> [AgentStreamEvent] {
        AgentStreamEvent.parse(Data(line.utf8), agent: agent)
    }

    @Test func claudeCodesSessionTextToolsAndEnd() {
        let input = Data(#"{"url":"https://example.com"}"#.utf8)
        #expect(events(#"{"type":"system","subtype":"hook_started","session_id":"s1"}"#, .claudeCode).isEmpty)
        #expect(events(#"{"type":"system","subtype":"init","session_id":"s1","model":"claude-haiku-4-5"}"#, .claudeCode) == [.session("s1")])
        #expect(events(#"{"type":"assistant","message":{"content":[{"type":"thinking","thinking":""}]}}"#, .claudeCode).isEmpty)
        #expect(events(
            #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_1","name":"mcp__reco__inspect_page","input":{"url":"https://example.com"}}]}}"#,
            .claudeCode
        ) == [.toolStarted(id: "toolu_1", tool: "inspect_page", input: input)])
        #expect(events(
            #"{"type":"user","message":{"content":[{"tool_use_id":"toolu_1","type":"tool_result","content":[{"type":"text","text":"{}"}]}]}}"#,
            .claudeCode
        ) == [.toolFinished(id: "toolu_1", isError: false)])
        #expect(events(#"{"type":"assistant","message":{"content":[{"type":"text","text":" Example Domain\n"}]}}"#, .claudeCode) == [.text("Example Domain")])
        #expect(events(#"{"type":"result","subtype":"success","is_error":false,"result":"Example Domain"}"#, .claudeCode) == [.finished(isError: false)])
        #expect(events(#"{"type":"rate_limit_event","rate_limit_info":{}}"#, .claudeCode).isEmpty)
    }

    @Test func aFailedClaudeToolCallIsAnError() {
        let line = #"{"type":"user","message":{"content":[{"tool_use_id":"toolu_2","type":"tool_result","is_error":true,"content":"busy"}]}}"#
        #expect(events(line, .claudeCode) == [.toolFinished(id: "toolu_2", isError: true)])
    }

    @Test func cursorsSessionTextToolsAndEnd() {
        #expect(events(#"{"type":"system","subtype":"init","session_id":"c1","model":"Auto"}"#, .cursor) == [.session("c1")])
        #expect(events(#"{"type":"thinking","subtype":"delta","text":"Calling","session_id":"c1"}"#, .cursor).isEmpty)
        // Looking the tool's schema up isn't a call to it
        let schema = #"{"type":"tool_call","subtype":"started","call_id":"a","tool_call":{"getMcpToolsToolCall":{"args":{"server":"reco","toolName":"inspect_page"}}}}"#
        #expect(events(schema, .cursor).isEmpty)
        let started = #"""
            {"type":"tool_call","subtype":"started","call_id":"b","tool_call":{"mcpToolCall":{"args":{"name":"reco-inspect_page",\#
            "args":{"url":"https://example.com"},"providerIdentifier":"reco","toolName":"inspect_page"}}}}
            """#
        #expect(events(started, .cursor) == [.toolStarted(id: "b", tool: "inspect_page", input: Data(#"{"url":"https://example.com"}"#.utf8))])
        let completed = #"""
            {"type":"tool_call","subtype":"completed","call_id":"b","tool_call":{"mcpToolCall":{"args":{"toolName":"inspect_page"},\#
            "result":{"success":{"content":[{"text":{"text":"{}"}}],"isError":false}}}}}
            """#
        #expect(events(completed, .cursor) == [.toolFinished(id: "b", isError: false)])
        #expect(events(#"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Example Domain"}]}}"#, .cursor) == [.text("Example Domain")])
        #expect(events(#"{"type":"result","subtype":"success","is_error":false,"result":"..."}"#, .cursor) == [.finished(isError: false)])
    }

    @Test func aCursorCallWithoutSuccessFailed() {
        let line = #"{"type":"tool_call","subtype":"completed","call_id":"b","tool_call":{"mcpToolCall":{"args":{},"result":{"error":{"message":"x"}}}}}"#
        #expect(events(line, .cursor) == [.toolFinished(id: "b", isError: true)])
    }

    @Test func linesThatArentJSONAreSkipped() {
        #expect(events("Warning: no stdin data received in 3s", .claudeCode).isEmpty)
        #expect(events("", .cursor).isEmpty)
    }

    @Test func onlyClaudeCodeAndCursorStream() {
        #expect(AgentKind.allCases.filter(AgentStreamEvent.streams) == [.claudeCode, .cursor])
    }
}
