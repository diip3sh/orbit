//
//  MotionEditorViewModel.swift
//  Reco
//

import AppKit
import AVFoundation
import OSLog

/// A motion bundle opened in its window: the document, its preview, its edits and its export.
@MainActor
@Observable
final class MotionEditorViewModel {

    let bundleURL: URL
    let playback = PlaybackController()

    var document: MotionDocument?

    /// The scene the inspector shows, by index, and the layer by id.
    var selectedScene = 0
    var selectedLayer: String?

    @ObservationIgnored let undoManager = UndoManager()
    @ObservationIgnored var coalescedEdits = EditCoalescing()
    @ObservationIgnored var rebuild: Task<Void, Never>?
    @ObservationIgnored var save: Task<Void, Never>?

    /// Why the bundle couldn't be opened or exported.
    var error: String?

    /// From 0 to 1 while an export runs.
    private(set) var exportProgress: Double?

    /// The preview is drawn at most this tall (its shorter side), whatever the canvas: a 4K frame
    /// with everything on is over the 8 ms budget (spec 0011, rendering spike).
    static let previewShorterSide: CGFloat = 1080

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "MotionEditorViewModel")

    init(bundleURL: URL) {
        self.bundleURL = bundleURL
    }

    var duration: Double {
        document?.duration ?? 0
    }

    func load() async {
        do {
            let document = try await MotionStore.read(bundleURL)
            try await preview(document, at: 0)
            self.document = document
        } catch {
            logger.error("Couldn't open \(self.bundleURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            self.error = error.localizedDescription
        }
    }

    /// Exports in `format` as `<name>-edited` next to the bundle and shows it in the Finder.
    /// Cancelling the calling task cancels the export.
    func export(_ format: ExportFormat) async {
        guard let document, exportProgress == nil else { return }
        exportProgress = 0
        defer { exportProgress = nil }
        do {
            let url = try await MotionExporter.export(document, bundle: bundleURL, settings: ExportSettings(format: format)) { [weak self] in
                self?.exportProgress = $0
            }
            logger.info("Exported \(url.lastPathComponent, privacy: .public)")
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            guard !Task.isCancelled else { return }
            logger.error("Export of \(self.bundleURL.lastPathComponent, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            self.error = error.localizedDescription
        }
    }

    /// Plays `document` from `time`, capturing the UI its plan needs first.
    func preview(_ document: MotionDocument, at time: Double) async throws {
        let canvas = document.canvas
        var plan = try await UICapture.plan(
            for: document, bundle: bundleURL, shorterSide: min(min(canvas.size.width, canvas.size.height), Self.previewShorterSide)
        )
        plan.isPreview = true
        let sound = try await SoundCache.sound(for: plan.sound, in: bundleURL)
        let composition = try await MotionCompositionBuilder.composition(for: plan, sound: sound)
        try Task.checkCancellation()
        playback.load(
            composition, frames: FrameGrid(frameRate: Double(plan.frameRate), duration: plan.duration),
            timescale: CMTimeScale(plan.frameRate), at: min(time, plan.duration)
        )
    }

    /// Releases the player, when the window closes, and saves what's left to save.
    func close() async {
        rebuild?.cancel()
        playback.release()
        await save?.value
    }
}
