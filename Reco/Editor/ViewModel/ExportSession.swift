//
//  ExportSession.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation

/// One visit to the export page: the settings chosen, the export running, and the file it wrote. Shared by the
/// page and the inspector column beside it, which shows the options.
@MainActor
@Observable
final class ExportSession {

    /// Another format, quality, size or frame rate is another file, exported again.
    var settings: ExportSettings {
        didSet {
            guard settings != oldValue else { return }
            exported = nil
            exportedBytes = nil
            copied = false
        }
    }

    private(set) var isExporting = false
    private(set) var exported: URL?

    /// Whether the last export went to the clipboard rather than a file.
    private(set) var copied = false

    /// The written file's size, once it exists.
    private(set) var exportedBytes: Int?

    private(set) var error: (any Error)?

    @ObservationIgnored private let viewModel: EditorViewModel
    @ObservationIgnored private var task: Task<Void, Never>?

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        settings = ExportSettings.initial(transparentCanvas: viewModel.canvas.background == .transparent)
    }

    /// Exports to a file next to the recording.
    func start() {
        run(to: .recordingFolder)
    }

    /// Exports to a temporary file and puts it on the pasteboard.
    func copy() {
        run(to: .clipboard)
    }

    private func run(to destination: ExportDestination) {
        guard !isExporting else { return }
        error = nil
        isExporting = true
        let settings = settings
        task = Task { [weak self, viewModel] in
            do {
                let url = try await viewModel.export(settings, to: destination)
                guard let self, !Task.isCancelled else { return }
                switch destination {
                case .recordingFolder:
                    exported = url
                    exportedBytes = url.flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
                case .clipboard:
                    if let url {
                        FilePasteboard.copy(file: url)
                        copied = true
                    }
                }
                isExporting = false
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.error = error
                isExporting = false
            }
        }
    }

    /// The file's estimated size in bytes for the settings, or for `quality` instead of the chosen one; `nil` for
    /// a GIF, or while the recording isn't loaded.
    func estimatedBytes(quality: ExportQuality? = nil) -> Int64? {
        guard let source = viewModel.source else { return nil }
        var settings = settings
        if let quality {
            settings.quality = quality
        }
        return settings.estimatedBytes(
            size: viewModel.exportSize(resolution: settings.resolution),
            frameRate: settings.outputFrameRate(recordingRate: source.frameRate),
            duration: viewModel.timeMap.outputDuration,
            hasAudio: !source.audioTrackIDs.isEmpty || viewModel.project.audio.addsAudio
        )
    }

    /// Stops a running export; cancelling the task cancels the export session.
    func cancel() {
        task?.cancel()
        task = nil
        isExporting = false
    }
}
