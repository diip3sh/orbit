//
//  AgentTranscript.swift
//  Reco
//

import Foundation

/// The agent chat (spec 0008): what the user asked, what the agent said, and the Reco tools it used,
/// in order, plus the conversation a follow-up goes into.
nonisolated struct AgentTranscript: Equatable, Sendable {

    nonisolated struct Entry: Identifiable, Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case request
            case reply
            case tool(ToolState)
        }

        enum ToolState: Equatable, Sendable {
            case running
            case done
            case failed
        }

        let id: String
        var kind: Kind
        var text: String
    }

    private(set) var entries: [Entry] = []

    /// The agent's conversation, once it has said which, and the agent it belongs to.
    private(set) var session: (id: String, agent: AgentKind)?

    /// What the agent last said, e.g. to explain a failure.
    var lastReply: String? {
        entries.last { $0.kind == .reply }?.text
    }

    /// The conversation a follow-up to `agent` continues, if it's that agent's.
    func sessionID(for agent: AgentKind) -> String? {
        session.flatMap { $0.agent == agent ? $0.id : nil }
    }

    mutating func addRequest(_ text: String) {
        entries.append(Entry(id: UUID().uuidString, kind: .request, text: text))
    }

    /// Adds what `agent` streamed. A render being checked again updates its row instead of adding one.
    mutating func apply(_ event: AgentStreamEvent, from agent: AgentKind) {
        switch event {
        case .session(let id):
            session = (id, agent)
        case .text(let text):
            entries.append(Entry(id: UUID().uuidString, kind: .reply, text: text))
        case .toolStarted(let id, let tool, let input):
            let text = Self.describe(tool: tool, input: input)
            if tool == AgentToolCatalog.renderStatus, let last = entries.indices.last, entries[last].text == text {
                entries[last] = Entry(id: id, kind: .tool(.running), text: text)
            } else {
                entries.append(Entry(id: id, kind: .tool(.running), text: text))
            }
        case .toolFinished(let id, let isError):
            if let index = entries.lastIndex(where: { $0.id == id }) {
                entries[index].kind = .tool(isError ? .failed : .done)
            }
        case .finished:
            // A run stopped mid-call leaves nothing spinning
            for index in entries.indices where entries[index].kind == .tool(.running) {
                entries[index].kind = .tool(.done)
            }
        }
    }

    /// What a Reco tool call does, in a few words: "Looking at buildonto.dev", "Recording 6 steps".
    static func describe(tool: String, input: Data) -> String {
        let arguments = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] ?? [:]
        switch tool {
        case AgentToolCatalog.inspectPage:
            let host = (arguments["url"] as? String).flatMap { URL(string: $0)?.host() }
            return host.map { "Looking at \($0)" } ?? "Looking at the page"
        case AgentToolCatalog.recordPage:
            let steps = (arguments["steps"] as? [Any])?.count ?? 0
            return steps == 1 ? "Planning 1 step" : "Planning \(steps) steps"
        case AgentToolCatalog.renderStatus:
            return "Rendering the video"
        case AgentToolCatalog.openPage:
            let host = (arguments["url"] as? String).flatMap { URL(string: $0)?.host() ?? URL(string: "https://\($0)")?.host() }
            return host.map { "Opening \($0)" } ?? "Opening the page"
        case AgentToolCatalog.look:
            return (arguments["y"] as? Double).map { $0 > 0 ? "Looking further down" : "Looking at the top" } ?? "Looking at the page"
        case AgentToolCatalog.readPage:
            return "Reading the page"
        case AgentToolCatalog.hover:
            return "Hovering over \(Self.elementName(arguments["selector"]))"
        case AgentToolCatalog.click:
            return "Clicking \(Self.elementName(arguments["selector"]))"
        case AgentToolCatalog.type:
            return "Typing “\(arguments["text"] as? String ?? "")”"
        default:
            return tool
        }
    }

    /// A selector's last step, e.g. `a.pricing` from `nav > a.pricing`, as the timeline names targets.
    private static func elementName(_ selector: Any?) -> String {
        guard let selector = selector as? String, let last = selector.split(separator: " > ").last else { return "an element" }
        return String(last)
    }

    static func == (lhs: AgentTranscript, rhs: AgentTranscript) -> Bool {
        lhs.entries == rhs.entries && lhs.session?.id == rhs.session?.id && lhs.session?.agent == rhs.session?.agent
    }
}
