//
//  AgentTools.swift
//  Reco
//

import CoreGraphics
import Foundation

/// Runs the tools an agent calls (spec 0006): inspect a page, record it, and follow the render.
///
/// A render takes longer than most agents wait for a tool, so `record_page` and `render_status` wait
/// up to ``waitLimit`` and report how far it is; the agent asks again. One render runs at a time and
/// only the latest is remembered.
@MainActor
@Observable
final class AgentTools {

    /// The latest render, or `nil` before the first. Only this type sets it, except in tests.
    var job: RenderStatus?

    /// Called with each page an agent inspects, for the Web Recording window to show (spec 0008).
    @ObservationIgnored var onInspected: ((PageInspection) -> Void)?

    /// Called with each script an agent's plan became, before it renders, for the window to adopt.
    @ObservationIgnored var onPlanned: ((WebScript) -> Void)?

    /// Whether an agent run Reco started (the bar or the chat) is going. Only then can an agent browse:
    /// the live page shares the default website data store, so it has the user's logins.
    /// ponytail: any connection may browse during such a run, not just its agent; tell them apart by a
    /// per-run token if that matters.
    @ObservationIgnored var hostsRun = false {
        didSet { recordings = 0 }
    }

    /// How many times `record_page` was called in the run going on.
    @ObservationIgnored private var recordings = 0

    /// How many times an agent Reco runs may call `record_page` in one run: a take and one more with its
    /// warnings fixed. An agent on a page whose warning re-recording can't fix would otherwise record forever.
    static let maximumRecordings = 2

    /// Whether `record_page` only puts the plan on the window's timeline, for the user to render: for
    /// the chat, where the user reviews and edits before rendering. Set for a run, cleared when it ends.
    @ObservationIgnored var stagesPlans = false

    /// The Web Recording window, opened if it isn't, whose live page an agent browses (spec 0011).
    @ObservationIgnored var browser: (() -> WebRecordingViewModel?)?

    /// A tool's answer: JSON text for the agent, and what the page looks like after a browsing step.
    struct Reply {
        var text: String
        var image: Data?
        var isError: Bool
    }

    /// How long a browsing step waits for the page to react before it looks: menus open, a click's
    /// page starts loading. A guess that covers typical transitions; not measured.
    static let settleTime = Duration.milliseconds(600)

    /// How much page text `read_page` returns, about 3,000 words.
    static let readLimit = 15_000

    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let onRendered: (URL) -> Void

    /// How long `record_page` and `render_status` wait for a render. Under the 60 s default tool
    /// timeout of Codex and Claude Desktop.
    static let waitLimit = Duration.seconds(45)

    /// How long `inspect_page` waits for a page, under the same timeout.
    static let inspectLimit = Duration.seconds(40)

    private static let pollInterval = Duration.milliseconds(250)

    /// - Parameter onRendered: Called with each rendered movie, to open it in the editor.
    init(settings: SettingsStore, onRendered: @escaping (URL) -> Void) {
        self.settings = settings
        self.onRendered = onRendered
    }

    /// Runs tool `name` with its JSON `arguments`. The text is JSON for the agent; a failure is
    /// reported as an error text, not thrown.
    func call(_ name: String, arguments: Data) async -> Reply {
        do {
            switch name {
            case AgentToolCatalog.inspectPage:
                return Reply(text: try Self.encode(try await inspect(arguments)), isError: false)
            case AgentToolCatalog.recordPage:
                let status = try await record(arguments)
                return Reply(text: try Self.encode(status), isError: status.status == .failed)
            case AgentToolCatalog.renderStatus:
                let status = try await status(arguments)
                return Reply(text: try Self.encode(status), isError: status.status == .failed)
            case AgentToolCatalog.openPage, AgentToolCatalog.look, AgentToolCatalog.readPage, AgentToolCatalog.click,
                 AgentToolCatalog.hover, AgentToolCatalog.type:
                guard hostsRun else {
                    throw AgentToolError.invalidArgument("Browsing works only in runs started from Orbit. Use inspect_page, then record_page.")
                }
                return try await browse(name, arguments: arguments)
            default:
                throw AgentToolError.unknownTool(name)
            }
        } catch {
            return Reply(text: error.localizedDescription, isError: true)
        }
    }

    // MARK: - Tools

    private func inspect(_ arguments: Data) async throws -> PageInspection {
        let script = try Self.decode(InspectPageRequest.self, from: arguments).validated()
        let page = try await Self.withDeadline(Self.inspectLimit) {
            try await WebPageRenderer(script: script).inspect(selectors: [])
        }
        onInspected?(page)
        return page
    }

    private func record(_ arguments: Data) async throws -> RenderStatus {
        let plan = try Self.decode(RecordPageRequest.self, from: arguments).plan()
        if let job, job.status == .rendering {
            throw AgentToolError.busy(renderID: job.renderID)
        }
        if hostsRun, recordings >= Self.maximumRecordings {
            throw AgentToolError.invalidArgument("This run has recorded \(recordings) times, the most it may. Report what the last result said.")
        }
        let id = UUID().uuidString
        if stagesPlans {
            let (script, warnings) = try await script(for: plan)
            recordings += 1
            var planned = RenderStatus(renderID: id, status: .planned, progress: 0)
            planned.warnings = warnings.isEmpty ? nil : warnings
            job = planned
            onPlanned?(script)
            return planned
        }
        recordings += 1
        job = RenderStatus(renderID: id, status: .rendering, progress: 0)
        renderTask = Task { await render(plan, id: id) }
        return try await wait(for: id)
    }

    private func status(_ arguments: Data) async throws -> RenderStatus {
        try await wait(for: try Self.decode(RenderStatusRequest.self, from: arguments).renderID)
    }

    // MARK: - Render

    /// Looks at the page to aim the plan, renders it and records the outcome in ``job``.
    private func render(_ plan: RecordPlan, id: String) async {
        do {
            let (script, _) = try await script(for: plan)
            onPlanned?(script)
            let (movie, warnings) = try await WebPageRenderer.renderTake(script, settings: settings) { [weak self] progress in
                self?.job?.progress = progress
            }
            job?.warnings = warnings.isEmpty ? nil : warnings
            job?.status = .done
            job?.progress = 1
            job?.movie = movie.path(percentEncoded: false)
            job?.telemetry = InputTelemetry.sidecarURL(for: movie).path(percentEncoded: false)
            onRendered(movie)
        } catch {
            job?.status = .failed
            job?.error = error.localizedDescription
        }
    }

    /// The plan as a script, aimed by looking at the page, and what the page lacks that its steps need.
    private func script(for plan: RecordPlan) async throws -> (WebScript, [String]) {
        let page = try await WebPageRenderer(script: plan.inspectionScript).inspect(selectors: plan.selectors)
        return try plan.script(page: page)
    }

    /// The render `id` once it's over, or as it is after ``waitLimit``.
    private func wait(for id: String) async throws -> RenderStatus {
        let deadline = ContinuousClock.now + Self.waitLimit
        while let job, job.renderID == id, job.status == .rendering, ContinuousClock.now < deadline {
            try await Task.sleep(for: Self.pollInterval)
        }
        guard let job, job.renderID == id else { throw AgentToolError.unknownRender }
        return job
    }

    // MARK: - Browsing

    /// One step of an agent learning a site in the window's live page: what it did, as JSON, and a
    /// picture of the page after it.
    private func browse(_ name: String, arguments: Data) async throws -> Reply {
        guard let window = browser?() else { throw AgentToolError.invalidArgument("The Web Recording window isn't available.") }
        let preview = window.preview
        let request = try Self.decode(BrowseRequest.self, from: arguments)
        var result: [String: Any] = [:]
        switch name {
        case AgentToolCatalog.openPage:
            let url = try RecordPageRequest.pageURL(request.url ?? "")
            let viewport = try RecordPageRequest.viewportSize(request.viewport)
            try await window.agentOpen(url, viewport: viewport)
            try await Task.sleep(for: Self.settleTime)
            let json = try await preview.evaluate(WebInspectScript.source, arguments: ["selectors": [String]()]) as? String ?? ""
            let page = try Self.decode(PageInspection.self, from: Data(json.utf8))
            window.showAgentInspection(page)
            return Reply(text: try Self.encode(page), image: try await preview.screenshot(), isError: false)
        case AgentToolCatalog.look:
            await preview.scroll(toY: max(0, request.y ?? 0))
        case AgentToolCatalog.readPage:
            let text = try await preview.evaluate(WebBrowseScript.read, arguments: ["limit": Self.readLimit]) as? String ?? "{}"
            return Reply(text: text, isError: false)
        case AgentToolCatalog.click, AgentToolCatalog.hover, AgentToolCatalog.type:
            let selector = try request.requiredSelector(for: name)
            guard let found = try await preview.evaluate(WebBrowseScript.locate, arguments: ["selector": selector]) as? [Any], found.count == 5,
                  let left = found[0] as? Double, let top = found[1] as? Double, let width = found[2] as? Double, let height = found[3] as? Double else {
                throw AgentToolError.invalidArgument("No element matches \"\(selector)\". Use a selector from open_page or inspect_page.")
            }
            let frame = CGRect(x: left, y: top, width: width, height: height)
            let center = CGPoint(x: frame.midX, y: frame.midY)
            window.showAgentTarget(frame)
            if name == AgentToolCatalog.hover {
                preview.hover(at: center)
            } else {
                preview.click(at: center)
            }
            if name == AgentToolCatalog.type {
                guard let text = request.text, !text.isEmpty else { throw AgentToolError.invalidArgument("type needs text.") }
                let typing = [WebScript.Typing(clip: UUID(), selector: selector, text: text)]
                _ = try await preview.evaluate(WebTypingScript.source, arguments: ["fields": WebTypingScript.fields(typing)])
            }
            result["element"] = found[4] as? String ?? ""
        default:
            throw AgentToolError.unknownTool(name)
        }
        try await Task.sleep(for: Self.settleTime)
        // A click may have opened another page: wait for it, and say so
        try await preview.waitUntilLoaded()
        if let position = try await preview.evaluate(WebBrowseScript.position) as? String,
           let object = try? JSONSerialization.jsonObject(with: Data(position.utf8)) as? [String: Any] {
            result.merge(object) { current, _ in current }
        }
        let text = String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys, .withoutEscapingSlashes]), encoding: .utf8) ?? "{}"
        return Reply(text: text, image: try await preview.screenshot(), isError: false)
    }

    // MARK: - JSON

    private static func encode(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(data: try encoder.encode(value), encoding: .utf8) ?? ""
    }

    private static func decode<Request: Decodable>(_ type: Request.Type, from data: Data) throws(AgentToolError) -> Request {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw .invalidArgument("The arguments are wrong at \"\(error.location)\": check the tool's input schema.")
        } catch {
            throw .invalidArgument("The arguments aren't valid JSON.")
        }
    }

    /// `work`'s result, or ``AgentToolError/timedOut`` when it takes longer than `limit`.
    private static func withDeadline<Result: Sendable>(
        _ limit: Duration, _ work: @escaping @MainActor @Sendable () async throws -> Result
    ) async throws -> Result {
        try await withThrowingTaskGroup(of: Result.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: limit)
                throw AgentToolError.timedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw AgentToolError.timedOut }
            return result
        }
    }
}

private extension DecodingError {

    /// The dotted path of the key at fault.
    var location: String {
        let path: [any CodingKey] = switch self {
        case .keyNotFound(let key, let context): context.codingPath + [key]
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context): context.codingPath
        @unknown default: []
        }
        return path.map(\.stringValue).joined(separator: ".")
    }
}
