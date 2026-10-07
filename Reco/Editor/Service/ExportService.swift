//
//  ExportService.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation
import OSLog

/// Writes an edited video, from the same composition the preview plays, so the file matches what the editor
/// shows: a movie through ``MovieEncoder``, a GIF through ``GIFEncoder``.
enum ExportService {

    private static let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "ExportService")

    /// Exports to `url`, replacing any file there, and reports progress from 0 to 1. The composition's own size
    /// and frame rate are the file's. Cancelling the calling task stops the export. A partial file is removed.
    static func export(
        _ composition: EditorComposition, to url: URL, as settings: ExportSettings, progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let signpost = signposter.beginInterval("Export")
        defer { signposter.endInterval("Export", signpost) }
        let report: @Sendable (Double) -> Void = { fraction in
            Task { @MainActor in progress(fraction) }
        }

        try? FileManager.default.removeItem(at: url)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            switch settings.format {
            case .mp4, .proRes: try await MovieEncoder.write(composition, to: url, as: settings, progress: report)
            case .gif: try await GIFEncoder.write(composition, to: url, progress: report)
            }
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }
}
