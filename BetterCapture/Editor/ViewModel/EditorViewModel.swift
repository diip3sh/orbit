//
//  EditorViewModel.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import CoreGraphics
import Foundation
import OSLog

/// State and intents of one editor window: the recording, its project and playback.
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
    private(set) var timeMap = TimeMap(cuts: [], sourceDuration: 0)

    /// Clicks and keystrokes on the timeline, or `nil` without telemetry.
    private(set) var markers: TimelineMarkers?

    /// The filmstrip, left to right.
    private(set) var thumbnails: [CGImage?] = []

    /// Why the recording couldn't be opened, while ``source`` is `nil`, or why edits weren't saved.
    private(set) var error: EditorError?

    /// The project as last read from or written to disk.
    @ObservationIgnored private var savedProject = EditorProject()
    @ObservationIgnored private var autosave: Task<Void, Never>?

    /// How long edits must settle before they are saved.
    private static let autosaveDelay = Duration.seconds(1)

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
        guard !Task.isCancelled else { return }

        self.source = source
        self.project = project
        savedProject = project
        playback.load(source)
        updateTimeline()
        logger.info("Opened \(self.videoURL.lastPathComponent)")
    }

    /// Loads the filmstrip for `count` tiles of at most `maximumSize` pixels. Cancelled when the
    /// timeline's layout changes.
    func loadThumbnails(count: Int, maximumSize: CGSize) async {
        guard let source, count > 0 else { return }
        let tileDuration = timeMap.outputDuration / Double(count)
        let times = (0..<count).map { timeMap.sourceTime(atOutput: (Double($0) + 0.5) * tileDuration) }
        let images = await ThumbnailProvider.thumbnails(of: source, at: times, maximumSize: maximumSize)
        guard !Task.isCancelled else { return }
        thumbnails = images
    }

    /// Applies an edit as one undo step named `actionName`, then saves once edits settle.
    func edit(_ actionName: String, _ change: (inout EditorProject) -> Void) {
        var edited = project
        change(&edited)
        setProject(edited, actionName: actionName)
    }

    /// Releases the player and filmstrip and saves pending edits. Called when the window closes.
    func close() async {
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
            viewModel.setProject(previous, actionName: actionName)
        }
        undoManager.setActionName(actionName)
        updateTimeline()
        scheduleAutosave()
    }

    private func updateTimeline() {
        guard let source else { return }
        timeMap = TimeMap(cuts: project.cuts, sourceDuration: source.duration)
        markers = source.telemetry.map { TimelineMarkers(telemetry: $0, timeMap: timeMap) }
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
