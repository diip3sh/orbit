//
//  AgentTools.swift
//  Reco
//

import Foundation

/// Runs the tools an agent calls (spec 0006): inspect a page, record it, follow the render and
/// export the recording.
///
/// A render takes longer than most agents wait for a tool, so `record_page` and `render_status` wait
/// up to ``waitLimit`` and report how far it is; the agent asks again. One render runs at a time and
/// only the latest is remembered.
@MainActor
@Observable
final class AgentTools {

    /// The latest render, or `nil` before the first. Only this type sets it, except in tests.
    var job: RenderStatus?

    /// The page an `inspect_page` call is looking at now, if one is.
    private(set) var inspecting: URL?

    /// What a motion tool is doing now ("Capturing the UI…"), if one is.
    var motionActivity: String?

    /// How many motion videos `edit_motion` has changed since launch, and the last: a run that
    /// edited one succeeded without rendering (spec 0011, *Agent*).
    var motionEdits = 0
    var lastMotionBundle: URL?

    /// The open window's view model of a motion bundle, which edits go through: the file is never
    /// changed behind an open window.
    @ObservationIgnored var motionEditor: (URL) -> MotionEditorViewModel? = { _ in nil }

    /// Called with each motion video `edit_motion` changes.
    @ObservationIgnored var onMotionEdited: (URL) -> Void = { _ in }

    /// The capture or preview going on or last finished, by its arguments.
    @ObservationIgnored var motionJob: MotionJob?

    struct MotionJob {
        let key: String
        let task: Task<Reply, Never>
        var isDone = false
    }

    @ObservationIgnored private var renderTask: Task<Void, Never>?

    /// The latest export and what asked for it, or `nil` before the first.
    @ObservationIgnored private var export: (request: ExportRecordingRequest, status: ExportStatus)?
    @ObservationIgnored private var exportTask: Task<Void, Never>?
    @ObservationIgnored let settings: SettingsStore
    @ObservationIgnored private let onRendered: (URL) -> Void

    /// How long `record_page` and `render_status` wait for a render. Under the 60 s default tool
    /// timeout of Codex and Claude Desktop.
    static let waitLimit = Duration.seconds(45)

    /// How long `inspect_page` waits for a page, under the same timeout.
    static let inspectLimit = Duration.seconds(40)

    static let pollInterval = Duration.milliseconds(250)

    /// A tool's answer: JSON text for the agent, and a picture for `preview_motion`.
    nonisolated struct Reply: Sendable {
        var text: String
        var image: Data?
        var isError: Bool

        init(text: String, image: Data? = nil, isError: Bool) {
            self.text = text
            self.image = image
            self.isError = isError
        }
    }

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
            case AgentToolCatalog.exportRecording:
                let status = try await export(arguments)
                return Reply(text: try Self.encode(status), isError: status.status == .failed)
            case AgentToolCatalog.editMotion:
                return Reply(text: try Self.encode(try await editMotion(arguments)), isError: false)
            case AgentToolCatalog.captureUI:
                return try await captureUI(arguments)
            case AgentToolCatalog.previewMotion:
                return try await previewMotion(arguments)
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
        inspecting = script.url
        defer { inspecting = nil }
        return try await Self.withDeadline(Self.inspectLimit) {
            try await WebPageRenderer(script: script).inspect(selectors: [])
        }
    }

    private func record(_ arguments: Data) async throws -> RenderStatus {
        let plan = try Self.decode(RecordPageRequest.self, from: arguments).plan()
        if let job, job.status == .rendering {
            throw AgentToolError.busy(renderID: job.renderID)
        }
        let id = UUID().uuidString
        job = RenderStatus(renderID: id, status: .rendering, progress: 0)
        renderTask = Task { await render(plan, id: id) }
        return try await wait(for: id)
    }

    private func status(_ arguments: Data) async throws -> RenderStatus {
        try await wait(for: try Self.decode(RenderStatusRequest.self, from: arguments).renderID)
    }

    /// Starts the export, or follows it when it's the one already running, for up to ``waitLimit``.
    private func export(_ arguments: Data) async throws -> ExportStatus {
        let request = try Self.decode(ExportRecordingRequest.self, from: arguments)
        let (movie, settings) = try request.validated()
        if let export, export.status.status == .exporting {
            guard export.request == request else { throw AgentToolError.exporting }
        } else {
            export = (request, ExportStatus(status: .exporting, progress: 0))
            exportTask = Task {
                do {
                    // Progress comes from its own task, which can still report after the export has returned
                    let progress = { [weak self] (progress: Double) in
                        if self?.export?.status.status == .exporting {
                            self?.export?.status.progress = progress
                        }
                    }
                    let file = if movie.pathExtension == MotionStore.bundleExtension {
                        try await MotionExporter.export(try await motionDocument(at: movie), bundle: movie, settings: settings, progress: progress)
                    } else {
                        try await ExportService.export(recordingAt: movie, settings: settings, progress: progress)
                    }
                    export?.status = ExportStatus(status: .done, progress: 1, file: file.path(percentEncoded: false))
                } catch {
                    export?.status.status = .failed
                    export?.status.error = error.localizedDescription
                }
            }
        }

        let deadline = ContinuousClock.now + Self.waitLimit
        while let export, export.status.status == .exporting, ContinuousClock.now < deadline {
            try await Task.sleep(for: Self.pollInterval)
        }
        return export?.status ?? ExportStatus(status: .failed, progress: 0)
    }

    // MARK: - Render

    /// Looks at the page to aim the plan, renders it and records the outcome in ``job``.
    private func render(_ plan: RecordPlan, id: String) async {
        do {
            let page = try await WebPageRenderer(script: plan.inspectionScript).inspect(selectors: plan.selectors)
            let (script, unmatched) = try plan.script(page: page)
            job?.unmatchedSelectors = unmatched.isEmpty ? nil : unmatched
            let take = try await WebPageRenderer.renderTake(script, settings: settings) { [weak self] progress in
                self?.job?.progress = progress
            }
            job?.status = .done
            job?.progress = 1
            job?.movie = take.movie.path(percentEncoded: false)
            job?.telemetry = InputTelemetry.sidecarURL(for: take.movie).path(percentEncoded: false)
            job?.warnings = take.issues.isEmpty ? nil : take.issues
            onRendered(take.movie)
        } catch {
            job?.status = .failed
            job?.error = error.localizedDescription
        }
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

    // MARK: - JSON

    static func encode(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(data: try encoder.encode(value), encoding: .utf8) ?? ""
    }

    static func decode<Request: Decodable>(_ type: Request.Type, from data: Data) throws(AgentToolError) -> Request {
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
