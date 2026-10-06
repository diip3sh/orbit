//
//  MotionExporter.swift
//  Reco
//

import Foundation

/// Exports a motion video through the same composition the preview plays, so the file matches it.
enum MotionExporter {

    /// Exports `document` at the settings' size and frame rate, fitted to what its format offers
    /// (a GIF is 540 px at 25 fps unless chosen), and returns the file: `<name>-edited` next to the
    /// bundle, which keeps it out of the Recordings list like every export.
    static func export(
        _ document: MotionDocument, bundle: URL, settings: ExportSettings, progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let canvas = document.canvas
        let settings = settings.conformed(shorterSide: min(canvas.size.width, canvas.size.height), frameRate: Double(canvas.frameRate))
        let plan = try await UICapture.plan(
            for: document, bundle: bundle, shorterSide: settings.resolution.map { CGFloat($0) }, frameRate: settings.frameRate
        )
        let composition = try await MotionCompositionBuilder.composition(for: plan)
        let url = settings.format.outputURL(for: bundle)
        try await ExportService.export(composition, to: url, as: settings.format, progress: progress)
        return url
    }
}
