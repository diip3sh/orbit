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
    ///
    /// Up to twice the canvas: a motion video is drawn, not scaled, and its UI is lifted again at
    /// the scale shown, so a 1080p canvas exports as sharp 4K.
    static func export(
        _ document: MotionDocument, bundle: URL, settings: ExportSettings, progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let canvas = document.canvas
        let settings = settings.conformed(shorterSide: 2 * min(canvas.size.width, canvas.size.height) + 1, frameRate: Double(canvas.frameRate))
        let plan = try await UICapture.plan(
            for: document, bundle: bundle, shorterSide: settings.resolution.map { CGFloat($0) }, frameRate: settings.frameRate
        )
        let composition = try await MotionCompositionBuilder.composition(for: plan)
        let url = settings.format.outputURL(for: bundle)
        try await ExportService.export(composition, to: url, as: settings.format, progress: progress)
        return url
    }
}
