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

    /// Another format, size or frame rate is another file, exported again.
    var settings: ExportSettings {
        didSet {
            guard settings != oldValue else { return }
            exported = nil
            exportedBytes = nil
        }
    }

    private(set) var isExporting = false
    private(set) var exported: URL?

    /// The written file's size, once it exists.
    private(set) var exportedBytes: Int?

    private(set) var error: (any Error)?

    @ObservationIgnored private let viewModel: EditorViewModel
    @ObservationIgnored private var task: Task<Void, Never>?

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        settings = ExportSettings.initial(transparentCanvas: viewModel.canvas.background == .transparent)
    }

    func start() {
        guard !isExporting else { return }
        error = nil
        isExporting = true
        let settings = settings
        task = Task { [weak self, viewModel] in
            do {
                let url = try await viewModel.export(settings)
                guard let self, !Task.isCancelled else { return }
                exported = url
                exportedBytes = url.flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
                isExporting = false
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.error = error
                isExporting = false
            }
        }
    }

    /// Stops a running export; cancelling the task cancels the export session.
    func cancel() {
        task?.cancel()
        task = nil
        isExporting = false
    }
}
