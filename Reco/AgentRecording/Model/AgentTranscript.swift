//
//  AgentTranscript.swift
//  Reco
//

import Foundation

/// The agent chat (spec 0008): what the user asked, what the agent said, and the Reco tools it used,
/// in order, plus the conversation a follow-up goes into.
nonisolated struct AgentTranscript: Equatable, Sendable {

    // The entry's kind and tool status belong to its transcript row.
    // swiftlint:disable nesting
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
    // swiftlint:enable nesting

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
            return host.map { String(localized: "Looking at \($0)") } ?? String(localized: "Looking at the page")
        case AgentToolCatalog.recordPage:
            let steps = (arguments["steps"] as? [Any])?.count ?? 0
            return steps == 1 ? String(localized: "Planning 1 step") : String(localized: "Planning \(steps) steps")
        case AgentToolCatalog.renderStatus:
            return String(localized: "Rendering the video")
        case AgentToolCatalog.openPage:
            let host = (arguments["url"] as? String).flatMap { URL(string: $0)?.host() ?? URL(string: "https://\($0)")?.host() }
            return host.map { String(localized: "Opening \($0)") } ?? String(localized: "Opening the page")
        case AgentToolCatalog.look:
            return Self.lookDescription(scrolledTo: arguments["y"] as? Double)
        case AgentToolCatalog.readPage:
            return String(localized: "Reading the page")
        case AgentToolCatalog.hover:
            let element = Self.elementName(arguments["selector"])
            return String(localized: "Hovering over \(element)")
        case AgentToolCatalog.click:
            let element = Self.elementName(arguments["selector"])
            return String(localized: "Clicking \(element)")
        case AgentToolCatalog.type:
            let typed = arguments["text"] as? String ?? ""
            return String(localized: "Typing “\(typed)”")
        default:
            return tool
        }
    }

    private static func lookDescription(scrolledTo offset: Double?) -> String {
        guard let offset else { return String(localized: "Looking at the page") }
        return offset > 0 ? String(localized: "Looking further down") : String(localized: "Looking at the top")
    }

    /// A selector's last step, e.g. `a.pricing` from `nav > a.pricing`, as the timeline names targets.
    private static func elementName(_ selector: Any?) -> String {
        guard let selector = selector as? String, let last = selector.split(separator: " > ").last else { return String(localized: "an element") }
        return String(last)
    }

    /// A message the chat draws as one bubble, or the run of tool steps between messages as one card.
    nonisolated enum Group: Identifiable, Equatable, Sendable {
        case request(Entry)
        case reply(Entry)
        case tools([Entry])

        /// The first entry's, so a card keeps its identity while steps join it.
        var id: String {
            switch self {
            case .request(let entry), .reply(let entry): entry.id
            case .tools(let entries): entries[0].id
            }
        }
    }

    /// The entries as the chat shows them: consecutive tool steps together.
    var groups: [Group] {
        var groups: [Group] = []
        for entry in entries {
            switch entry.kind {
            case .request: groups.append(.request(entry))
            case .reply: groups.append(.reply(entry))
            case .tool:
                if case .tools(let steps)? = groups.last {
                    groups[groups.count - 1] = .tools(steps + [entry])
                } else {
                    groups.append(.tools([entry]))
                }
            }
        }
        return groups
    }

    static func == (lhs: AgentTranscript, rhs: AgentTranscript) -> Bool {
        lhs.entries == rhs.entries && lhs.session?.id == rhs.session?.id && lhs.session?.agent == rhs.session?.agent
    }
}
