//
//  ExportService.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation
import OSLog

/// Writes an edited video with `AVAssetExportSession`, from the same composition the preview
/// plays, so the file matches what the editor shows.
enum ExportService {

    private static let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "ExportService")

    /// Exports to `url`, replacing any file there, and reports progress from 0 to 1. Cancelling the
    /// calling task stops the export. A partial file is removed.
    static func export(
        _ composition: EditorComposition, to url: URL, as format: ExportFormat, progress: @escaping (Double) -> Void
    ) async throws {
        guard let session = AVAssetExportSession(asset: composition.asset, presetName: format.preset) else {
            throw CocoaError(.featureUnsupported)
        }
        session.videoComposition = composition.videoComposition
        session.audioMix = composition.audioMix

        let signpost = signposter.beginInterval("Export")
        defer { signposter.endInterval("Export", signpost) }
        let states = session.states(updateInterval: 0.1)
        let progressUpdates = Task {
            for await case .exporting(let exportProgress) in states {
                progress(exportProgress.fractionCompleted)
            }
        }
        defer { progressUpdates.cancel() }

        try? FileManager.default.removeItem(at: url)
        do {
            try await session.export(to: url, as: format.fileType)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }
}
