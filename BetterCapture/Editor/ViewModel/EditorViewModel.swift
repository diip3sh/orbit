//
//  EditorViewModel.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import AppKit
import CoreGraphics
import Foundation
import OSLog

/// State and intents of one editor window: the recording, its project, playback and export.
@MainActor
@Observable
final class EditorViewModel {

    let videoURL: URL
    let playback = PlaybackController()

    /// The window's undo manager. ``EditorWindowManager`` hands it to AppKit, so ⌘Z and ⇧⌘Z reach it.
    @ObservationIgnored let undoManager = UndoManager()

    /// The recording, or `nil` while it loads or when it couldn't be opened.
    private(set) var source: EditorSource?
    private(set) var project = EditorProject()
    private(set) var timeMap = TimeMap(cuts: [], sourceDuration: 0, frameRate: 60)

    /// The part of the timeline that ⌫ cuts, in source seconds: a segment between splits and cuts.
    private(set) var selection: Range<Double>?

    /// Clicks and keystrokes on the timeline, or `nil` without telemetry.
    private(set) var markers: TimelineMarkers?

    /// The filmstrip, left to right.
    private(set) var thumbnails: [CGImage?] = []

    /// Why the recording couldn't be opened, while ``source`` is `nil`, or why edits weren't saved.
    private(set) var error: EditorError?

    /// How far an export is, from 0 to 1, or `nil` when none is running.
    private(set) var exportProgress: Double?

    /// The project as last read from or written to disk.
    @ObservationIgnored private var savedProject = EditorProject()
    @ObservationIgnored private var autosave: Task<Void, Never>?

    /// What the player shows and export writes. Behind the project while a rebuild runs.
    @ObservationIgnored private var plan: RenderPlan?
    @ObservationIgnored private var composition: EditorComposition?
    @ObservationIgnored private var rebuild: Task<Void, Never>?

    /// Labels keystrokes with the keyboard layout in use when the editor opened.
    @ObservationIgnored private var keyLabels: KeyLabelFormatter?

    /// The latest coalescing edit, which the next one with the same name joins if it follows soon enough.
    @ObservationIgnored private var coalescingEdit: (actionName: String, time: ContinuousClock.Instant)?

    /// How long edits must settle before they are saved.
    private static let autosaveDelay = Duration.seconds(1)

    /// How soon a coalescing edit must follow the previous one to join its undo step.
    private static let coalescingInterval = Duration.seconds(1)

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "EditorViewModel")

    init(videoURL: URL) {
        self.videoURL = videoURL
    }

    /// Loads the recording and its project; the window shows a placeholder meanwhile.
    func load() async {
        guard source == nil else { return }
        let source: EditorSource
        let project: EditorProject
        do {
            source = try await EditorSourceLoader.load(videoURL: videoURL)
        } catch {
            fail(error as? EditorError ?? .unreadableVideo(error))
            return
        }
        do {
            project = try await ProjectStore.read(for: videoURL) ?? EditorProject()
        } catch {
            fail(.unreadableProject(error))
            return
        }
        let keyLabels = KeyLabelFormatter.current()
        let plan = await RenderPlan.build(project: project, source: source, keyLabels: keyLabels)
        let composition: EditorComposition
        do {
            composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        } catch {
            fail(.unreadableVideo(error))
            return
        }
        guard !Task.isCancelled else { return }

        self.source = source
        self.project = project
        self.keyLabels = keyLabels
        savedProject = project
        markers = source.telemetry.map(TimelineMarkers.init)
        updateTimeline()
        show(composition, plan: plan, atSource: 0)
        logger.info("Opened \(self.videoURL.lastPathComponent)")
    }

    /// Loads the filmstrip for `count` tiles of at most `maximumSize` pixels. Cancelled when the
    /// timeline's layout changes.
    func loadThumbnails(count: Int, maximumSize: CGSize) async {
        guard let source, count > 0 else { return }
        let times = (0..<count).map { (Double($0) + 0.5) * source.duration / Double(count) }
        let images = await ThumbnailProvider.thumbnails(of: source, at: times, maximumSize: maximumSize)
        guard !Task.isCancelled else { return }
        thumbnails = images
    }

    /// Applies an edit as one undo step named `actionName`, then saves once edits settle.
    ///
    /// With `coalescing`, an edit with the same name within a second of the previous one joins its
    /// undo step, so dragging a slider or a color is undone at once.
    func edit(_ actionName: String, coalescing: Bool = false, _ change: (inout EditorProject) -> Void) {
        var edited = project
        change(&edited)
        guard edited != project else { return }

        let now = ContinuousClock.now
        if coalescing, let last = coalescingEdit, last.actionName == actionName, now - last.time < Self.coalescingInterval {
            // The undo step the first of these edits registered restores the project from before all of them
            let previous = project
            project = edited
            projectChanged(from: previous)
        } else {
            setProject(edited, actionName: actionName)
        }
        coalescingEdit = coalescing ? (actionName, now) : nil
    }

    /// The click highlight style, for the inspector's controls. Each change is an edit.
    var clickHighlights: ClickHighlightStyle {
        get { project.clickHighlights }
        set { edit("Click Highlights", coalescing: true) { $0.clickHighlights = newValue } }
    }

    /// The keystroke overlay style, for the inspector's controls. Each change is an edit.
    var keystrokes: KeystrokeOverlayStyle {
        get { project.keystrokes }
        set { edit("Keystrokes", coalescing: true) { $0.keystrokes = newValue } }
    }

    /// The audio tracks' volumes, for the inspector's controls. Each change is an edit.
    var audio: AudioMixSettings {
        get { project.audio }
        set { edit("Audio", coalescing: true) { $0.audio = newValue } }
    }

    /// Exports the edited video as `<name>-edited` next to the recording and reveals it in Finder.
    /// Cancelling the calling task cancels the export.
    func export(as format: ExportFormat) async throws {
        await rebuild?.value
        guard let composition else { return }
        let url = format.outputURL(for: videoURL)
        exportProgress = 0
        defer { exportProgress = nil }

        do {
            try await ExportService.export(composition, to: url, as: format) { [weak self] in
                self?.exportProgress = $0
            }
        } catch {
            guard !Task.isCancelled else { throw CancellationError() }
            logger.error("Export of \(self.videoURL.lastPathComponent) failed: \(error.localizedDescription)")
            throw EditorError.exportFailed(error)
        }
        logger.info("Exported \(url.lastPathComponent)")
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Releases the player and filmstrip and saves pending edits. Called when the window closes.
    func close() async {
        rebuild?.cancel()
        playback.release()
        thumbnails = []
        autosave?.cancel()
        await autosave?.value
        await save()
    }

    // MARK: - Private

    /// Replaces the project, registering the previous one for undo (and so, when undoing, for redo).
    private func setProject(_ newProject: EditorProject, actionName: String) {
        guard newProject != project else { return }
        let previous = project
        project = newProject
        coalescingEdit = nil
        undoManager.registerUndo(withTarget: self) { viewModel in
            viewModel.setProject(previous, actionName: actionName)
        }
        undoManager.setActionName(actionName)
        projectChanged(from: previous)
    }

    private func projectChanged(from previous: EditorProject) {
        selection = nil
        updateTimeline()
        // Splits and volumes aren't drawn; anything else is
        var drawn = project
        drawn.splits = previous.splits
        drawn.audio = previous.audio
        if drawn != previous {
            rebuildPlan()
        } else if project.audio != previous.audio, let source, let plan {
            let audioMix = CompositionBuilder.audioMix(for: source, timeMap: plan.timeMap, settings: project.audio)
            composition?.audioMix = audioMix
            playback.setAudioMix(audioMix)
        }
        scheduleAutosave()
    }

    private func updateTimeline() {
        guard let source else { return }
        timeMap = TimeMap(cuts: project.cuts, sourceDuration: source.duration, frameRate: source.frameRate)
    }

    /// Builds a plan for the project off the main actor, replacing a build still running, and shows
    /// it. New cuts need a new player item, whose playhead stays on the same content.
    private func rebuildPlan() {
        guard let source else { return }
        rebuild?.cancel()
        let project = project
        let keyLabels = keyLabels
        rebuild = Task {
            let plan = await RenderPlan.build(project: project, source: source, keyLabels: keyLabels)
            guard !Task.isCancelled, let playing = self.plan, var composition else { return }
            guard plan.timeMap != playing.timeMap else {
                composition.videoComposition = CompositionBuilder.videoComposition(for: source, plan: plan)
                composition.audioMix = CompositionBuilder.audioMix(for: source, timeMap: plan.timeMap, settings: self.project.audio)
                self.plan = plan
                self.composition = composition
                playback.setVideoComposition(composition.videoComposition)
                playback.setAudioMix(composition.audioMix)
                return
            }

            let playhead = playing.timeMap.sourceTime(atOutput: playback.currentTime)
            do {
                let rebuilt = try await CompositionBuilder.composition(for: source, plan: plan, audio: self.project.audio)
                guard !Task.isCancelled else { return }
                show(rebuilt, plan: plan, atSource: playhead)
            } catch {
                fail(.unreadableVideo(error))
            }
        }
    }

    /// Plays a new composition, paused at source time `time` or the first frame after it.
    private func show(_ composition: EditorComposition, plan: RenderPlan, atSource time: Double) {
        guard let source else { return }
        self.plan = plan
        self.composition = composition
        let frames = FrameGrid(frameRate: source.frameRate, duration: plan.timeMap.outputDuration)
        playback.load(composition, frames: frames, timescale: source.timescale, at: plan.timeMap.outputTime(atSource: time))
    }

    private func scheduleAutosave() {
        autosave?.cancel()
        autosave = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            await self?.save()
        }
    }

    private func save() async {
        guard project != savedProject else { return }
        let project = project
        do {
            try await ProjectStore.write(project, for: videoURL)
            savedProject = project
        } catch {
            fail(.projectNotSaved(error))
        }
    }

    private func fail(_ error: EditorError) {
        logger.error("\(self.videoURL.lastPathComponent): \(error.localizedDescription)")
        self.error = error
    }
}

// MARK: - Cutting

extension EditorViewModel {

    /// The kept ranges divided at the project's splits: what can be selected.
    var segments: [Range<Double>] {
        timeMap.segments(splitAt: project.splits)
    }

    /// The playhead in source seconds. Not observed during playback.
    var playheadSourceTime: Double {
        timeMap.sourceTime(atOutput: playback.currentTime)
    }

    /// Something must stay, so the only segment left can't be cut.
    var canCutSelection: Bool {
        selection != nil && segments.count > 1
    }

    /// Shows the frame at source time `time`, or the first one after it inside a cut.
    func seek(toSource time: Double) {
        playback.seek(to: timeMap.outputTime(atSource: time))
    }

    /// Selects the segment at source time `time`; inside a cut, nothing.
    func select(at time: Double) {
        selection = segments.first { $0.contains(time) }
    }

    /// Divides the segment under the playhead in two, at the frame shown.
    func split() {
        let splits = (project.splits + [timeMap.snapped(playheadSourceTime)]).sorted()
        guard timeMap.segments(splitAt: splits) != segments else { return }
        edit("Split") { $0.splits = splits }
    }

    func cutSelection() {
        guard let selection, canCutSelection else { return }
        edit("Cut") { $0.cuts = timeMap.cuts(adding: selection) }
    }

    /// Moves kept range `index`'s start to source time `time`, cutting or restoring the recording there.
    func moveStart(ofKeptRange index: Int, to time: Double) {
        edit("Trim") { $0.cuts = timeMap.cuts(movingStartOf: index, to: time) }
    }

    /// Moves kept range `index`'s end to source time `time`, cutting or restoring the recording there.
    func moveEnd(ofKeptRange index: Int, to time: Double) {
        edit("Trim") { $0.cuts = timeMap.cuts(movingEndOf: index, to: time) }
    }
}
