//
//  WebPageRenderer+Take.swift
//  Reco
//

import Foundation
import OSLog

// MARK: - Output folder

extension WebPageRenderer {

    /// Renders `script` into a new movie in the output folder, with its telemetry and script beside
    /// it, and returns the movie and what went wrong on the page. A failed or cancelled take leaves
    /// no movie.
    static func renderTake(_ script: WebScript, settings: SettingsStore, progress: (Double) -> Void) async throws -> (movie: URL, issues: [String]) {
        let accessesOutputDirectory = settings.startAccessingOutputDirectory()
        defer {
            if accessesOutputDirectory {
                settings.stopAccessingOutputDirectory()
            }
        }
        let filename = SettingsStore.filename(prefix: "Reco_Web", fileExtension: "mov", date: .now)
        let movie = settings.outputDirectory.appending(path: filename)
        do {
            let rendered = try await WebPageRenderer(script: script).render(
                to: movie, bitsPerPixel: VideoQuality.high.hevcBitsPerPixel, progress: progress
            )
            try JSONEncoder().encode(rendered.telemetry).write(to: InputTelemetry.sidecarURL(for: movie), options: .atomic)
            try await WebTake(script: script).write(for: movie)
            // A script that chooses its zooms opens with them and no others: its project is saved before the editor opens
            if script.pointer.contains(where: { $0.show != nil }) {
                try await ProjectStore.write(EditorProject(zooms: rendered.zooms), for: movie)
            }
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "WebPageRenderer").info("Rendered \(filename)")
            return (movie, rendered.issues)
        } catch {
            try? FileManager.default.removeItem(at: movie)
            throw error
        }
    }
}
