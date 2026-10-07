//
//  EditorViewModel.swift
//  Reco
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

    private(set) var selection: EditorSelection?

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

    /// The keyboard layout in use when the editor opened, the system's arrow for recordings made
    /// without the cursor, and the background picture.
    @ObservationIgnored private var resources = RenderResources.none

    /// The bookmark whose picture is in ``resources``.
    @ObservationIgnored private var backgroundBookmark: Data?

    /// Which edits share an undo step.
    @ObservationIgnored private var coalescedEdits = EditCoalescing()

    /// How long edits must settle before they are saved.
    private static let autosaveDelay = Duration.seconds(1)

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "EditorViewModel")

    /// The look a new project starts with, from the take this one replaces in its window.
    @ObservationIgnored private let style: EditorProject?

    init(videoURL: URL, style: EditorProject? = nil) {
        self.videoURL = videoURL
        self.style = style
    }

    /// Loads the recording and its project; the window shows a placeholder meanwhile.
    func load() async {
        guard source == nil else { return }
        let source: EditorSource
        let project: EditorProject
        let saved: EditorProject
        do {
            source = try await EditorSourceLoader.load(videoURL: videoURL)
        } catch {
            fail(error as? EditorError ?? .unreadableVideo(error))
            return
        }
        do {
            // A new project starts with the automatic zooms, and is saved only once edited or restyled
            let stored = try await ProjectStore.read(for: videoURL)
            saved = stored ?? EditorProject(zooms: source.telemetry.map { AutoZoomGenerator.segments(for: $0, duration: source.duration) } ?? [])
            project = stored ?? style.map(saved.styled(like:)) ?? saved
        } catch {
            fail(.unreadableProject(error))
            return
        }
        var resources = RenderResources(
            keyLabels: KeyLabelFormatter.current(),
            arrow: source.telemetry?.capture.cursorInVideo == false ? StandardCursors.arrowSprite : nil
        )
        if let bookmark = project.canvas.imageBookmark {
            resources.background = await BackgroundImageLoader.image(from: bookmark)
        }
        let plan = await RenderPlan.build(project: project, source: source, resources: resources)
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
        self.resources = resources
        backgroundBookmark = project.canvas.imageBookmark
        savedProject = saved
        if project != saved {
            scheduleAutosave()
        }
        markers = source.telemetry.map(TimelineMarkers.init)
        updateTimeline()
        show(composition, plan: plan, atSource: 0)
        if project.canvas.imageBookmark != nil, resources.background == nil {
            fail(.unreadableBackground)
        }
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

        if coalescedEdits.joinsPrevious(actionName, coalescing: coalescing) {
            // The undo step the first of these edits registered restores the project from before all of them
            let previous = project
            project = edited
            projectChanged(from: previous)
        } else {
            setProject(edited, actionName: actionName)
        }
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

    /// The drawn cursor's style, for the inspector's controls. Each change is an edit.
    var cursor: CursorStyle {
        get { project.cursor }
        set { edit("Cursor", coalescing: true) { $0.cursor = newValue } }
    }

    /// The canvas's style, for the inspector's controls. Each change is an edit.
    var canvas: CanvasStyle {
        get { project.canvas }
        set { edit("Canvas", coalescing: true) { $0.canvas = newValue } }
    }

    /// Makes the picture at `url`, chosen by the user, the canvas's background.
    func setBackgroundImage(_ url: URL) {
        do {
            let bookmark = try BackgroundImageLoader.bookmark(for: url)
            edit("Background Image") {
                $0.canvas.background = .image
                $0.canvas.imageBookmark = bookmark
            }
        } catch {
            logger.error("No bookmark for \(url.lastPathComponent): \(error.localizedDescription)")
            fail(.unreadableBackground)
        }
    }

    /// The audio tracks' volumes, for the inspector's controls. Each change is an edit.
    var audio: AudioMixSettings {
        get { project.audio }
        set { edit("Audio", coalescing: true) { $0.audio = newValue } }
    }

    /// The exported frame's size for a shorter side of `resolution` pixels, or the canvas's own.
    func exportSize(resolution: Int?) -> CGSize {
        guard let source else { return .zero }
        return CanvasLayout.size(for: source.naturalSize, aspect: project.canvas.aspect, shorterSide: resolution.map { CGFloat($0) })
    }

    /// Exports the edited video as `<name>-edited` next to the recording and reveals it in Finder.
    /// Cancelling the calling task cancels the export.
    func export(_ settings: ExportSettings) async throws {
        await rebuild?.value
        guard let source, var composition else { return }
        // Drawn at the export's size, frame rate and dynamic range; otherwise the same as the preview
        let target = RenderTarget(shorterSide: settings.resolution.map { CGFloat($0) }, keepsHDR: settings.format.keepsHDR)
        let plan = await RenderPlan.build(project: project, source: source, resources: resources, target: target)
        composition.videoComposition = CompositionBuilder.videoComposition(for: source, plan: plan, frameRate: settings.frameRate.map { Double($0) })
        let url = settings.format.outputURL(for: videoURL)
        exportProgress = 0
        defer { exportProgress = nil }

        do {
            try await ExportService.export(composition, to: url, as: settings.format) { [weak self] in
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
        undoManager.registerUndo(withTarget: self) { viewModel in
            viewModel.coalescedEdits.reset()
            viewModel.setProject(previous, actionName: actionName)
        }
        undoManager.setActionName(actionName)
        projectChanged(from: previous)
    }

    private func projectChanged(from previous: EditorProject) {
        // A zoom stays selected while it's being changed
        if selectedZoom == nil {
            selection = nil
        }
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
        rebuild = Task {
            let bookmark = project.canvas.imageBookmark
            if bookmark != backgroundBookmark {
                resources.background = nil
                if let bookmark {
                    resources.background = await BackgroundImageLoader.image(from: bookmark)
                    if resources.background == nil {
                        fail(.unreadableBackground)
                    }
                }
                backgroundBookmark = bookmark
            }
            let plan = await RenderPlan.build(project: project, source: source, resources: resources)
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
    var canDeleteSelection: Bool {
        switch selection {
        case .segment: segments.count > 1
        case .zoom: true
        case nil: false
        }
    }

    /// Shows the frame at source time `time`, or the first one after it inside a cut.
    func seek(toSource time: Double) {
        playback.seek(to: timeMap.outputTime(atSource: time))
    }

    /// Selects the segment at source time `time`; inside a cut, nothing.
    func select(at time: Double) {
        selection = segments.first { $0.contains(time) }.map(EditorSelection.segment)
    }

    /// Divides the segment under the playhead in two, at the frame shown.
    func split() {
        let splits = (project.splits + [timeMap.snapped(playheadSourceTime)]).sorted()
        guard timeMap.segments(splitAt: splits) != segments else { return }
        edit("Split") { $0.splits = splits }
    }

    /// Cuts the selected segment or deletes the selected zoom.
    func deleteSelection() {
        guard let selection, canDeleteSelection else { return }
        switch selection {
        case .segment(let range):
            edit("Cut") { $0.cuts = timeMap.cuts(adding: range) }
        case .zoom(let id):
            edit("Delete Zoom") { $0.zooms = $0.zooms.removing(id) }
        }
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

// MARK: - Zooming

extension EditorViewModel {

    /// The selected zoom, for the inspector's controls. Each change is an edit, which makes it manual.
    var selectedZoom: ZoomSegment? {
        get {
            guard case .zoom(let id) = selection else { return nil }
            return project.zooms.first { $0.id == id }
        }
        set {
            guard let newValue else { return }
            edit("Zoom", coalescing: true) { $0.zooms = $0.zooms.replacing(newValue) }
        }
    }

    /// Whether a zoom can start at the playhead: it's outside the others, with room for the shortest.
    var canAddZoom: Bool {
        newZoomAtPlayhead != nil
    }

    func selectZoom(_ id: ZoomSegment.ID) {
        selection = .zoom(id)
    }

    /// Adds a zoom at the playhead and selects it. It follows the cursor when there is one to follow.
    func addZoom() {
        guard let zoom = newZoomAtPlayhead else { return }
        edit("Add Zoom") { $0.zooms = $0.zooms.inserting(zoom) }
        selection = .zoom(zoom.id)
    }

    /// Moves a zoom by `offset` seconds, up to its neighbours and the recording's ends.
    func moveZoom(_ id: ZoomSegment.ID, by offset: Double) {
        guard let source else { return }
        edit("Move Zoom") { $0.zooms = $0.zooms.moving(id, by: offset, duration: source.duration) }
    }

    func moveZoomStart(_ id: ZoomSegment.ID, to time: Double) {
        edit("Resize Zoom") { $0.zooms = $0.zooms.movingStart(of: id, to: time) }
    }

    func moveZoomEnd(_ id: ZoomSegment.ID, to time: Double) {
        guard let source else { return }
        edit("Resize Zoom") { $0.zooms = $0.zooms.movingEnd(of: id, to: time, duration: source.duration) }
    }

    /// Replaces the automatic zooms with new ones from the telemetry, keeping the manual ones.
    func regenerateZooms() {
        guard let source, let telemetry = source.telemetry else { return }
        let generated = AutoZoomGenerator.segments(for: telemetry, duration: source.duration)
        edit("Regenerate Zooms") { $0.zooms = $0.zooms.regenerated(with: generated) }
    }

    /// Whether zoomed parts look soft: the recording has fewer than 2 video pixels per screen
    /// point, e.g. a Retina display recorded without Native Resolution.
    var zoomsLookSoft: Bool {
        (source?.telemetry?.pixelsPerPoint ?? 2) < 2
    }

    /// The filmstrip's picture nearest source time `time`, once loaded.
    func thumbnail(at time: Double) -> CGImage? {
        guard !thumbnails.isEmpty, timeMap.sourceDuration > 0 else { return nil }
        let index = Int(time / timeMap.sourceDuration * Double(thumbnails.count))
        return thumbnails[min(max(index, 0), thumbnails.count - 1)]
    }

    private var newZoomAtPlayhead: ZoomSegment? {
        guard let source else { return nil }
        let focus: ZoomSegment.Focus = source.telemetry?.cursor.isEmpty == false ? .followCursor : .fixed(center: CGPoint(x: 0.5, y: 0.5))
        return project.zooms.newZoom(at: timeMap.snapped(playheadSourceTime), focus: focus, duration: source.duration)
    }
}
