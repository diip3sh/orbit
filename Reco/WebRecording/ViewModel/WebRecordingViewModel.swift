//
//  WebRecordingViewModel.swift
//  Reco
//

import AppKit
import Foundation
import OSLog

/// State and intents of the Web Recording window: the script and its timeline, the live page, pick
/// mode and the render.
@MainActor
@Observable
final class WebRecordingViewModel {

    private(set) var script: WebScript

    /// The selected clip, on either lane. Choosing anything but a cursor clip stops pick mode.
    var selection: UUID? {
        didSet {
            if isPicking, selectedPointerClip == nil {
                setPicking(false)
            }
        }
    }

    /// The timeline's time, in seconds.
    private(set) var playhead = 0.0

    /// Whether the next click in the page picks the selected cursor clip's target.
    private(set) var isPicking = false

    /// Where the cursor is at the playhead, in viewport CSS pixels.
    private(set) var cursorPreview: CGPoint?

    /// How far a render is, from 0 to 1, or `nil` when none is running.
    private(set) var renderProgress: Double?

    /// Why the last render failed.
    var renderError: String?

    /// The address field's text. Committing it loads the page.
    var address: String

    /// The window's undo manager. ``EditorWindowManager`` hands it to AppKit, so ⌘Z and ⇧⌘Z reach it.
    @ObservationIgnored let undoManager = UndoManager()
    @ObservationIgnored let preview: WebPreviewController

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let storeURL: URL
    @ObservationIgnored private let onRendered: (URL) -> Void
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var showTask: Task<Void, Never>?

    /// Which edits share an undo step.
    @ObservationIgnored private var coalescedEdits = EditCoalescing()

    /// How long edits must settle before the script is saved.
    private static let saveDelay = Duration.seconds(1)

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "WebRecordingViewModel")

    /// - Parameters:
    ///   - storeURL: Where the script is kept between launches.
    ///   - onRendered: Called with each rendered movie, to open it in the editor.
    init(settings: SettingsStore, storeURL: URL = WebScriptStore.defaultURL, onRendered: @escaping (URL) -> Void) {
        let script = WebScriptStore.read(from: storeURL) ?? WebScript()
        self.settings = settings
        self.storeURL = storeURL
        self.onRendered = onRendered
        self.script = script
        address = script.url?.absoluteString ?? ""
        preview = WebPreviewController(viewport: script.viewport)
        preview.onPick = { [weak self] target in self?.picked(target) }
        if let url = script.url {
            preview.load(url)
        }
    }

    // MARK: - Editing

    /// Applies an edit as one undo step named `actionName`, then saves once edits settle.
    ///
    /// With `coalescing`, an edit with the same name within a second of the previous one joins its
    /// undo step, so dragging a slider is undone at once.
    func edit(_ actionName: String, coalescing: Bool = false, _ change: (inout WebScript) -> Void) {
        var edited = script
        change(&edited)
        guard edited != script else { return }

        if coalescedEdits.joinsPrevious(actionName, coalescing: coalescing) {
            // The undo step the first of these edits registered restores the script from before all of them
            let previous = script
            script = edited
            scriptChanged(from: previous)
        } else {
            setScript(edited, actionName: actionName)
        }
    }

    private func setScript(_ newScript: WebScript, actionName: String) {
        guard newScript != script else { return }
        let previous = script
        script = newScript
        undoManager.registerUndo(withTarget: self) { viewModel in
            viewModel.coalescedEdits.reset()
            viewModel.setScript(previous, actionName: actionName)
        }
        undoManager.setActionName(actionName)
        scriptChanged(from: previous)
    }

    private func scriptChanged(from previous: WebScript) {
        if selectedPointerClip == nil, selectedScrollClip == nil {
            selection = nil
        }
        if script.viewport != previous.viewport {
            preview.viewport = script.viewport
        }
        // Undoing a new address goes back to the page before, or to none
        if script.url != previous.url {
            address = script.url?.absoluteString ?? ""
            preview.load(script.url)
        }
        playhead = min(playhead, script.duration)
        showPlayhead(scrolling: false)
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let script = script
        let storeURL = storeURL
        saveTask = Task { [logger] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            do {
                try WebScriptStore.write(script, to: storeURL)
            } catch {
                logger.error("Couldn't save the web script: \(error.localizedDescription)")
            }
        }
    }

    /// Saves at once and stops a render, when the window closes.
    func close() {
        saveTask?.cancel()
        renderTask?.cancel()
        try? WebScriptStore.write(script, to: storeURL)
    }

    // MARK: - Page

    /// Loads the address typed: `https://` is added when it has no scheme, `http://` for local
    /// servers.
    func commitAddress() {
        guard let url = WebScript.url(from: address) else { return }
        address = url.absoluteString
        if url == script.url {
            preview.load(url)
        } else {
            // Loads it, as undoing it loads the page before
            edit("Change Page") { $0.url = url }
        }
    }

    /// Loads the script's page again, e.g. after following links in it.
    func reload() {
        if let url = script.url {
            preview.load(url)
        }
    }

    /// The viewport preset in use, or `nil` for another size.
    var viewport: WebScript.Viewport? {
        get { WebScript.Viewport.allCases.first { $0.size == script.viewport } }
        set {
            guard let newValue else { return }
            edit("Viewport") { $0.viewport = newValue.size }
        }
    }

    var scale: Int {
        get { script.scale }
        set { edit("Scale") { $0.scale = newValue } }
    }

    /// The script's length. It can't cut a clip or go beyond ``WebScript/maximumDuration``.
    var duration: Double {
        get { script.duration }
        set { edit("Length", coalescing: true) { $0.duration = min(max(newValue, $0.minimumAllowedDuration), WebScript.maximumDuration) } }
    }

    // MARK: - Clips

    /// The selected cursor clip, for the inspector. Setting it is an edit; its range stays.
    var selectedPointerClip: PointerClip? {
        get { script.pointer.first { $0.id == selection } }
        set {
            guard var clip = newValue, let current = selectedPointerClip else { return }
            clip.range = current.range
            edit("Cursor Clip", coalescing: true) { $0.pointer = $0.pointer.replacing(clip) }
        }
    }

    /// The selected scroll clip, for the inspector. Setting it is an edit; its range stays.
    var selectedScrollClip: ScrollClip? {
        get { script.scrolls.first { $0.id == selection } }
        set {
            guard var clip = newValue, let current = selectedScrollClip else { return }
            clip.range = current.range
            edit("Scroll Clip", coalescing: true) { $0.scrolls = $0.scrolls.replacing(clip) }
        }
    }

    /// Where the selected scroll clip scrolls to, in CSS pixels from the page's top.
    var selectedScrollY: Double {
        get { selectedScrollClip.map { Double($0.offset.y) } ?? 0 }
        set {
            guard var clip = selectedScrollClip else { return }
            clip.offset.y = max(newValue, 0)
            selectedScrollClip = clip
        }
    }

    var canAddPointerClip: Bool {
        script.pointer.room(at: playhead, length: PointerClip.defaultDuration, duration: script.duration) != nil
    }

    var canAddScrollClip: Bool {
        script.scrolls.room(at: playhead, length: ScrollClip.defaultDuration, duration: script.duration) != nil
    }

    /// Adds a hover or click at the playhead, aimed where the cursor is then, and starts pick mode
    /// so the next click in the page aims it.
    func addPointerClip(_ action: PointerClip.Action) {
        guard let range = script.pointer.room(at: playhead, length: PointerClip.defaultDuration, duration: script.duration) else { return }
        let target = script.pointer.last { $0.range.lowerBound <= playhead }?.target
            ?? WebTarget(point: CGPoint(x: script.viewport.width / 2, y: script.viewport.height / 2))
        let clip = PointerClip(range: range, action: action, target: target)
        edit(action == .click ? "Add Click" : "Add Hover") { $0.pointer = $0.pointer.inserting(clip) }
        selection = clip.id
        setPicking(true)
    }

    /// Adds a scroll at the playhead to where the page is scrolled now.
    func addScrollClip() async {
        let offset = await preview.scrollOffset() ?? script.scrollOffset(at: playhead)
        guard let range = script.scrolls.room(at: playhead, length: ScrollClip.defaultDuration, duration: script.duration) else { return }
        let clip = ScrollClip(range: range, offset: offset)
        edit("Add Scroll") { $0.scrolls = $0.scrolls.inserting(clip) }
        selection = clip.id
    }

    /// Makes the selected scroll clip end where the page is scrolled now.
    func useCurrentScroll() async {
        guard var clip = selectedScrollClip, let offset = await preview.scrollOffset() else { return }
        clip.offset = offset
        selectedScrollClip = clip
    }

    func moveClip(_ id: UUID, by offset: Double) {
        edit("Move Clip") {
            $0.pointer = $0.pointer.moving(id, by: offset, duration: $0.duration)
            $0.scrolls = $0.scrolls.moving(id, by: offset, duration: $0.duration)
        }
    }

    func moveClipStart(_ id: UUID, to time: Double) {
        edit("Resize Clip") {
            $0.pointer = $0.pointer.movingStart(of: id, to: time)
            $0.scrolls = $0.scrolls.movingStart(of: id, to: time)
        }
    }

    func moveClipEnd(_ id: UUID, to time: Double) {
        edit("Resize Clip") {
            $0.pointer = $0.pointer.movingEnd(of: id, to: time, duration: $0.duration)
            $0.scrolls = $0.scrolls.movingEnd(of: id, to: time, duration: $0.duration)
        }
    }

    /// When the selected clip starts, for the inspector. Setting it moves the clip within its lane.
    var selectionStart: Double {
        get { selectedRange?.lowerBound ?? 0 }
        set {
            guard let id = selection, let range = selectedRange else { return }
            moveClip(id, by: newValue - range.lowerBound)
        }
    }

    /// How long the selected clip lasts, for the inspector. Setting it moves the clip's end.
    var selectionLength: Double {
        get { selectedRange.map { $0.upperBound - $0.lowerBound } ?? 0 }
        set {
            guard let id = selection, let range = selectedRange else { return }
            moveClipEnd(id, to: range.lowerBound + newValue)
        }
    }

    private var selectedRange: Range<Double>? {
        selectedPointerClip?.range ?? selectedScrollClip?.range
    }

    func deleteSelection() {
        guard let id = selection else { return }
        edit("Delete Clip") {
            $0.pointer = $0.pointer.removing(id)
            $0.scrolls = $0.scrolls.removing(id)
        }
    }

    // MARK: - Playhead and picking

    /// Moves the playhead to `time`, and the page and its cursor to where the script has them then.
    func seek(to time: Double) {
        playhead = min(max(time, 0), script.duration)
        showPlayhead(scrolling: true)
    }

    /// Places the cursor preview at the playhead, scrolling the page there when `scrolling`: edits
    /// leave the page where the user scrolled it, e.g. to add a scroll clip.
    private func showPlayhead(scrolling: Bool) {
        showTask?.cancel()
        let script = script
        let time = playhead
        showTask = Task {
            let location = await preview.show(script, at: time, scrolling: scrolling)
            guard !Task.isCancelled else { return }
            cursorPreview = location
        }
    }

    func togglePicking() {
        setPicking(!isPicking)
    }

    private func setPicking(_ isPicking: Bool) {
        self.isPicking = isPicking && selectedPointerClip != nil
        preview.setPicking(self.isPicking)
    }

    private func picked(_ target: WebTarget) {
        if var clip = selectedPointerClip {
            clip.target = target
            edit("Pick Target") { $0.pointer = $0.pointer.replacing(clip) }
        }
        setPicking(false)
    }
}

// MARK: - Rendering

extension WebRecordingViewModel {

    var canRender: Bool {
        script.url != nil && renderProgress == nil
    }

    /// Renders the script into the output folder, then hands the movie to ``onRendered``.
    func render() {
        guard canRender else { return }
        setPicking(false)
        renderError = nil
        renderProgress = 0
        let script = script
        renderTask = Task {
            defer {
                renderProgress = nil
                renderTask = nil
            }
            do {
                let take = try await WebPageRenderer.renderTake(script, settings: settings) { [weak self] progress in
                    self?.renderProgress = progress
                }
                onRendered(take.movie)
            } catch {
                if !(error is CancellationError) {
                    logger.error("Couldn't render the web script: \(error.localizedDescription)")
                    renderError = error.localizedDescription
                }
            }
        }
    }

    func cancelRender() {
        renderTask?.cancel()
    }
}
