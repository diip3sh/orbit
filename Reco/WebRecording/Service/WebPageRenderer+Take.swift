//
//  WebPageRenderer+Take.swift
//  Reco
//

import OSLog
import WebKit

extension WebPageRenderer {

    /// Loads the script's page and lists what it shows at scroll 0: see ``WebInspectScript``.
    /// `selectors` are the ones to also return the box of.
    func inspect(selectors: [String]) async throws -> PageInspection {
        // Settled in real time, as in a take: the page's own scripts finish drawing before it's read
        try await withLoadedPage { webView in
            let result = try await webView.callAsyncJavaScript(
                WebInspectScript.source, arguments: ["selectors": selectors], contentWorld: .defaultClient
            )
            guard let json = result as? String else { throw WebRenderError.loadFailed("The page couldn't be read.") }
            var inspection = try JSONDecoder().decode(PageInspection.self, from: Data(json.utf8))
            inspection.renderCost = try await renderCost()
            return inspection
        }
    }

    /// Seconds of rendering per second of video at scale 1 and 2, from one snapshot of the page at
    /// each: the snapshot is the cost of a frame, 14 ms on a simple page and 310 ms on linear.app at
    /// 2× (M5), the rest of a frame a few ms. Lets an agent choose a scale the run's time allows.
    private func renderCost() async throws -> [String: Double] {
        var cost: [String: Double] = [:]
        for scale in [1, 2] {
            let start = ContinuousClock.now
            _ = try await snapshot(scale: scale)
            let seconds = (ContinuousClock.now - start) / .seconds(1)
            cost[String(scale)] = (seconds * Double(WebScript.frameRate) * 100).rounded() / 100
        }
        return cost
    }

    /// Renders `script` into a new movie in the output folder, with its telemetry and editor project
    /// beside it, and returns the movie and what went wrong on the page. A failed or cancelled take
    /// leaves no movie.
    static func renderTake(_ script: WebScript, settings: SettingsStore, progress: (Double) -> Void) async throws -> (movie: URL, warnings: [String]) {
        let accessesOutputDirectory = settings.startAccessingOutputDirectory()
        defer {
            if accessesOutputDirectory {
                settings.stopAccessingOutputDirectory()
            }
        }
        let filename = SettingsStore.filename(prefix: "Reco_Web", fileExtension: "mov", date: .now)
        let movie = settings.outputDirectory.appending(path: filename)
        do {
            let output = try await WebPageRenderer(script: script).render(
                to: movie, bitsPerPixel: VideoQuality.high.hevcBitsPerPixel, progress: progress
            )
            try JSONEncoder().encode(output.telemetry).write(to: InputTelemetry.sidecarURL(for: movie), options: .atomic)
            try await WebTake(script: script).write(for: movie)
            // The script's zooms, exactly, for the editor, even none when it shows elements; without
            // any it auto-zooms as on any recording
            let zooms = WebCamera.segments(for: script, telemetry: output.telemetry, shots: output.shots)
            if !zooms.isEmpty || WebCamera.showsElements(script) {
                try await ProjectStore.write(EditorProject(zooms: zooms), for: movie)
            }
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "WebPageRenderer").info("Rendered \(filename)")
            return (movie, output.warnings)
        } catch {
            try? FileManager.default.removeItem(at: movie)
            throw error
        }
    }
}
