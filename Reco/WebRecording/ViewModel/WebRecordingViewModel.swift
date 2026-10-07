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

    /// The inspector on the right, like the editor's, and the agent chat on the left, hidden until asked for.
    var showsInspector = true
    var showsAgent = false

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

    /// The box of the element the clip at the playhead shows, in viewport CSS pixels, for the camera.
    private(set) var shownPreview: CGRect?

    /// The elements an agent just found in the page, in viewport CSS pixels at the top of the page;
    /// shown for ``agentHighlightTime`` (spec 0008).
    private(set) var agentHighlights: [CGRect] = []

    /// Whether the script plays in the preview: the playhead moves in real time and the page and
    /// cursor follow.
    private(set) var isPlaying = false

    @ObservationIgnored private var highlightTask: Task<Void, Never>?
    @ObservationIgnored private var playTask: Task<Void, Never>?

    /// Whether playback's last page move is still going; the next waits, the playhead doesn't.
    @ObservationIgnored private var isMovingPage = false

    /// Playback has pressed and released up to here, so a press in a skipped page move still happens.
    @ObservationIgnored private var pressedThrough = -Double.infinity

    /// Where playback last moved the page's pointer; it moves it again only when the cursor moves, as a take does.
    @ObservationIgnored private var hovered: CGPoint?

    /// How often playback moves the page. The page is skipped while it's still busy with the last move,
    /// so playback stays in real time instead of queuing up behind it.
    static let playbackInterval = Duration.milliseconds(33)

    /// Long enough to see what the agent found, short enough not to linger over its next step.
    static let agentHighlightTime = Duration.seconds(4)

    /// How far a render is, from 0 to 1, or `nil` when none is running.
    private(set) var renderProgress: Double?

    /// Why the last render failed.
    var renderError: String?

    /// Why the page isn't showing: an address that isn't one, or a load that failed.
    var pageError: String?

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

    /// Starts a blank script, as New Web Recording means; one undoable step, so ⌘Z brings the last back.
    func startNew() {
        // A running render keeps its script; New waits for it
        guard isEditable, script != WebScript() else { return }
        stopPlaying()
        setPicking(false)
        selection = nil
        edit("New Web Recording") { $0 = WebScript() }
        address = ""
        seek(to: 0)
    }

    /// What a new type clip types until the user changes it.
    static let placeholderText = "Hello"

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
        preview.onLoadFailed = { [weak self] reason in self?.pageError = reason }
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
        // Every change comes through here, so this is where a render's script is kept as it is
        guard isEditable else { return }
        stopPlaying()
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
        guard isEditable else { return }
        guard let url = WebScript.url(from: address) else {
            pageError = address.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : "“\(address)” isn't a web address. Try one like apple.com or http://localhost:3000."
            return
        }
        pageError = nil
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
            pageError = nil
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

    /// Whether the script can change: not while it renders, which plays it as it was.
    var isEditable: Bool {
        renderProgress == nil
    }

    /// Whether Play has something to show: a page, and no render using the preview's time.
    var canPlay: Bool {
        script.url != nil && script.duration > 0 && isEditable
    }

    var canAddPointerClip: Bool {
        script.url != nil && isEditable && script.pointer.room(at: playhead, length: PointerClip.defaultDuration, duration: script.duration) != nil
    }

    var canAddScrollClip: Bool {
        script.url != nil && isEditable && script.scrolls.room(at: playhead, length: ScrollClip.defaultDuration, duration: script.duration) != nil
    }

    /// Adds a hover or click at the playhead, aimed where the cursor is then, and starts pick mode
    /// so the next click in the page aims it.
    func addPointerClip(_ action: PointerClip.Action) {
        // Room for a few words of typing; the inspector sets the text
        let length = action == .type ? PointerClip.typingDuration(for: Self.placeholderText) : PointerClip.defaultDuration
        guard let range = script.pointer.room(at: playhead, length: length, duration: script.duration) else { return }
        let target = script.pointer.last { $0.range.lowerBound <= playhead }?.target
            ?? WebTarget(point: CGPoint(x: script.viewport.width / 2, y: script.viewport.height / 2))
        let clip = PointerClip(range: range, action: action, target: target, text: action == .type ? Self.placeholderText : nil)
        edit("Add \(action.rawValue.capitalized)") { $0.pointer = $0.pointer.inserting(clip) }
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
        stopPlaying()
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
            let shown = await preview.show(script, at: time, scrolling: scrolling)
            guard !Task.isCancelled else { return }
            (cursorPreview, shownPreview) = shown
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
        stopPlaying()
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
                let movie = try await WebPageRenderer.renderTake(script, settings: settings) { [weak self] progress in
                    self?.renderProgress = progress
                }.movie
                onRendered(movie)
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

    /// Opens a movie this window rendered in the editor, e.g. from the agent chat's result card.
    func openInEditor(_ movie: URL) {
        onRendered(movie)
    }
}

// MARK: - Agent

/// What a coding agent does shows in the window as it does it (spec 0008): the elements it finds light
/// up, its plan becomes the timeline, and the playhead follows its render. The plan stays for the
/// user to take over and change.
extension WebRecordingViewModel {

    /// Lights up the elements an agent found, when it looked at this window's page.
    func showAgentInspection(_ page: PageInspection) {
        guard let url = script.url, URL(string: page.url)?.host() == url.host() else { return }
        // The boxes are at the page's top
        seek(to: 0)
        agentHighlights = page.elements.map(\.box.rect).filter { $0.minY < script.viewport.height }
        highlightTask?.cancel()
        highlightTask = Task {
            try? await Task.sleep(for: Self.agentHighlightTime)
            guard !Task.isCancelled else { return }
            agentHighlights = []
        }
    }

    /// Opens `url` in the live page for an agent learning the site (spec 0011), as the window's page,
    /// and waits for it. The user watches it load like any page they open.
    func agentOpen(_ url: URL, viewport: CGSize) async throws {
        guard isEditable else { throw AgentToolError.invalidArgument("The Web Recording window is rendering; try again when it's done.") }
        stopPlaying()
        setPicking(false)
        pageError = nil
        if script.viewport != viewport {
            edit("Change Viewport") { $0.viewport = viewport }
        }
        if script.url == url {
            preview.load(url)
        } else {
            address = url.absoluteString
            edit("Change Page") { $0.url = url }
        }
        try await preview.waitUntilLoaded()
    }

    /// Outlines what an agent is about to hover, click or type into, in viewport CSS pixels.
    func showAgentTarget(_ frame: CGRect) {
        agentHighlights = [frame]
        highlightTask?.cancel()
        highlightTask = Task {
            try? await Task.sleep(for: Self.agentHighlightTime)
            guard !Task.isCancelled else { return }
            agentHighlights = []
        }
    }

    /// Makes an agent's plan the window's script, as one undoable step, and plays it once, so the user
    /// watches the video the agent planned at its real pace while it renders, then can change its clips
    /// and render again. Following the render itself jumped: it runs slower than real time and unevenly.
    func adoptAgentScript(_ planned: WebScript) {
        setPicking(false)
        selection = nil
        edit("Agent's Script") { $0 = planned }
        seek(to: 0)
        togglePlayback()
    }
}

// MARK: - Playback

extension WebRecordingViewModel {

    /// Plays the script from the playhead (from the start when it's at the end), or pauses it.
    func togglePlayback() {
        if isPlaying {
            stopPlaying()
            return
        }
        guard script.duration > 0 else { return }
        setPicking(false)
        showTask?.cancel()
        if playhead >= script.duration {
            playhead = 0
        }
        isPlaying = true
        let start = playhead
        pressedThrough = start > 0 ? start : -.infinity
        hovered = nil
        playTask = Task {
            // A click played before may have left the page; playing from the start begins on it again
            if start == 0, let url = script.url, preview.currentURL != url {
                preview.load(url)
                try? await preview.waitUntilLoaded()
            }
            let clock = ContinuousClock()
            let began = clock.now
            while !Task.isCancelled {
                let time = min(start + began.duration(to: clock.now) / .seconds(1), script.duration)
                playhead = time
                movePage(to: time)
                if time >= script.duration {
                    break
                }
                try? await Task.sleep(for: Self.playbackInterval)
            }
            if !Task.isCancelled {
                isPlaying = false
                playTask = nil
            }
        }
    }

    /// Moves the page and cursor to `time`, unless the last move is still going: a busy page drops
    /// frames rather than holding the playhead back or piling moves up.
    private func movePage(to time: Double) {
        guard !isMovingPage else { return }
        isMovingPage = true
        let script = script
        let presses = script.presses(after: pressedThrough, through: time)
        pressedThrough = time
        Task {
            let (location, shown) = await preview.show(script, at: time, scrolling: true)
            // The page hears the pointer as in the take, so hovers and clicks happen while it plays
            if let location {
                if location != hovered {
                    preview.hover(at: location)
                    hovered = location
                }
                for press in presses {
                    preview.press(press.isDown, at: location)
                }
            }
            isMovingPage = false
            if isPlaying {
                (cursorPreview, shownPreview) = (location, shown)
            }
        }
    }

    func stopPlaying() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
    }
}
