//
//  ExportService.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation
import OSLog

/// Writes an edited video with `AVAssetExportSession`, or ``GIFWriter`` for a GIF, from the same
/// composition the preview plays, so the file matches what the editor shows.
enum ExportService {

    private static let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "ExportService")

    /// Exports the recording at `videoURL` with its saved edit, or as it would open in the editor,
    /// with `settings` fitted to it. Returns the file, `<name>-edited` next to the recording.
    static func export(recordingAt videoURL: URL, settings: ExportSettings, progress: @escaping (Double) -> Void) async throws -> URL {
        let source = try await EditorSourceLoader.load(videoURL: videoURL)
        let project = try await ProjectStore.read(for: videoURL) ?? EditorProject(opening: source)
        let canvas = CanvasLayout.size(for: source.naturalSize, aspect: project.canvas.aspect, shorterSide: nil)
        return try await export(
            project, of: source, resources: await RenderResources.current(for: source, project: project),
            settings: settings.conformed(shorterSide: min(canvas.width, canvas.height), frameRate: source.frameRate), progress: progress
        )
    }

    /// Exports `project`'s edit of `source`, drawn at the settings' size, frame rate and dynamic
    /// range and otherwise as the preview shows it. Returns the file, `<name>-edited` next to the recording.
    static func export(
        _ project: EditorProject, of source: EditorSource, resources: RenderResources, settings: ExportSettings,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let target = RenderTarget(shorterSide: settings.resolution.map { CGFloat($0) }, keepsHDR: settings.format.keepsHDR, blurSamples: 16)
        let plan = await RenderPlan.build(project: project, source: source, resources: resources, target: target)
        var composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        composition.videoComposition = CompositionBuilder.videoComposition(for: source, plan: plan, frameRate: settings.frameRate.map { Double($0) })
        let url = settings.format.outputURL(for: source.asset.url)
        try await export(composition, to: url, as: settings.format, progress: progress)
        return url
    }

    /// Exports to `url`, replacing any file there, and reports progress from 0 to 1. Cancelling the
    /// calling task stops the export. A partial file is removed.
    static func export(
        _ composition: EditorComposition, to url: URL, as format: ExportFormat, progress: @escaping (Double) -> Void
    ) async throws {
        guard let preset = format.preset, let fileType = format.fileType else {
            try await exportGIF(composition, to: url, progress: progress)
            return
        }
        guard let session = AVAssetExportSession(asset: composition.asset, presetName: preset) else {
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
            try await session.export(to: url, as: fileType)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    /// The frame at output time `time`, as an export at the composition's size draws it.
    static func frame(of composition: EditorComposition, at time: CMTime) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: composition.asset)
        generator.videoComposition = composition.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { image, _, error in
                continuation.resume(with: Result { try image ?? { throw error ?? CocoaError(.fileReadUnknown) }() })
            }
        }
    }

    private static func exportGIF(_ composition: EditorComposition, to url: URL, progress: @escaping (Double) -> Void) async throws {
        let signpost = signposter.beginInterval("ExportGIF")
        defer { signposter.endInterval("ExportGIF", signpost) }
        let (updates, continuation) = AsyncStream.makeStream(of: Double.self, bufferingPolicy: .bufferingNewest(1))
        let progressUpdates = Task {
            for await fraction in updates {
                progress(fraction)
            }
        }
        defer { progressUpdates.cancel() }

        // AVComposition isn't Sendable; this one is never changed once built
        nonisolated(unsafe) let asset = composition.asset
        try? FileManager.default.removeItem(at: url)
        do {
            try await GIFWriter.write(asset, videoComposition: composition.videoComposition, to: url) {
                continuation.yield($0)
            }
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }
}
