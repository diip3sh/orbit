//
//  AgentStreamEvent.swift
//  Reco
//

import Foundation

/// What an agent's `stream-json` output says as it works (spec 0008), the same for every agent that
/// streams. Claude Code and Cursor print one JSON object per line in formats that differ in their
/// details; ``parse(_:agent:)`` reads both.
nonisolated enum AgentStreamEvent: Equatable, Sendable {
    /// The conversation's ID, to send a follow-up into it.
    case session(String)
    /// Something the agent said.
    case text(String)
    /// A Reco tool call began; `input` is its arguments as JSON.
    case toolStarted(id: String, tool: String, input: Data)
    case toolFinished(id: String, isError: Bool)
    /// The agent is done with this message.
    case finished(isError: Bool)

    /// Whether `agent`'s runs print `stream-json` (see ``AgentInvocation/make(for:in:server:)``).
    static func streams(_ agent: AgentKind) -> Bool {
        agent == .claudeCode || agent == .cursor
    }

    /// The events in one line of `agent`'s output; none for lines it doesn't know or that aren't JSON.
    ///
    /// Measured on 2026-10-02 with Claude Code (`claude -p --output-format stream-json --verbose`) and
    /// cursor-agent 2026.09.10 (`--output-format stream-json`). Claude puts tool calls in `assistant`
    /// messages and results in `user` ones; Cursor sends `tool_call` events, started and completed, and
    /// first looks a tool's schema up through `getMcpToolsToolCall`, which isn't a call to it.
    static func parse(_ line: Data, agent: AgentKind) -> [AgentStreamEvent] {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let type = object["type"] as? String else { return [] }
        switch type {
        case "system":
            guard object["subtype"] as? String == "init", let id = object["session_id"] as? String else { return [] }
            return [.session(id)]
        case "assistant":
            return content(of: object).flatMap { item -> [AgentStreamEvent] in
                switch item["type"] as? String {
                case "text":
                    guard let text = (item["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return [] }
                    return [.text(text)]
                case "tool_use":
                    guard let id = item["id"] as? String, let name = item["name"] as? String else { return [] }
                    return [.toolStarted(id: id, tool: toolName(name), input: json(item["input"]))]
                default:
                    return []
                }
            }
        case "user":
            return content(of: object).compactMap { item in
                guard item["type"] as? String == "tool_result", let id = item["tool_use_id"] as? String else { return nil }
                return .toolFinished(id: id, isError: item["is_error"] as? Bool ?? false)
            }
        case "tool_call":
            guard let id = object["call_id"] as? String,
                  let call = (object["tool_call"] as? [String: Any])?["mcpToolCall"] as? [String: Any],
                  let arguments = call["args"] as? [String: Any] else { return [] }
            switch object["subtype"] as? String {
            case "started":
                let name = arguments["toolName"] as? String ?? arguments["name"] as? String ?? ""
                return [.toolStarted(id: id, tool: toolName(name), input: json(arguments["args"]))]
            case "completed":
                let result = call["result"] as? [String: Any]
                let success = result?["success"] as? [String: Any]
                return [.toolFinished(id: id, isError: success.map { $0["isError"] as? Bool ?? false } ?? true)]
            default:
                return []
            }
        case "result":
            return [.finished(isError: object["is_error"] as? Bool ?? (object["subtype"] as? String != "success"))]
        default:
            return []
        }
    }

    private static func content(of object: [String: Any]) -> [[String: Any]] {
        (object["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
    }

    /// `inspect_page` from `mcp__reco__inspect_page` (Claude) or `reco-inspect_page` (Cursor).
    private static func toolName(_ name: String) -> String {
        let afterServer = name.components(separatedBy: "__").last ?? name
        return afterServer.hasPrefix("reco-") ? String(afterServer.dropFirst(5)) : afterServer
    }

    private static func json(_ value: Any?) -> Data {
        guard let value, JSONSerialization.isValidJSONObject(value) else { return Data("{}".utf8) }
        return (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data("{}".utf8)
    }
}
