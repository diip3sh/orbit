//
//  MotionEditorViewModel.swift
//  Reco
//

import AppKit
import AVFoundation
import OSLog

/// A motion bundle opened in its window: the document, its preview and its export.
@MainActor
@Observable
final class MotionEditorViewModel {

    let bundleURL: URL
    let playback = PlaybackController()

    private(set) var document: MotionDocument?

    /// Why the bundle couldn't be opened or exported.
    private(set) var error: String?

    /// From 0 to 1 while an export runs.
    private(set) var exportProgress: Double?

    /// The preview is drawn at most this tall (its shorter side), whatever the canvas: a 4K frame
    /// with everything on is over the 8 ms budget (spec 0011, rendering spike).
    static let previewShorterSide: CGFloat = 1080

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "MotionEditorViewModel")

    init(bundleURL: URL) {
        self.bundleURL = bundleURL
    }

    var duration: Double {
        document?.duration ?? 0
    }

    func load() async {
        do {
            let document = try await MotionStore.read(bundleURL)
            let canvas = document.canvas
            let plan = try await UICapture.plan(
                for: document, bundle: bundleURL, shorterSide: min(min(canvas.size.width, canvas.size.height), Self.previewShorterSide)
            )
            let composition = try await MotionCompositionBuilder.composition(for: plan)
            self.document = document
            playback.load(
                composition, frames: FrameGrid(frameRate: Double(plan.frameRate), duration: plan.duration),
                timescale: CMTimeScale(plan.frameRate), at: 0
            )
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

    /// Releases the player, when the window closes.
    func close() {
        playback.release()
    }
}
