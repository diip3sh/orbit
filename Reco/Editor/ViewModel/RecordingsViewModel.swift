//
//  RecordingsViewModel.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Foundation
import OSLog

/// The Recordings window's state: the output folder's recordings and their pictures.
@MainActor
@Observable
final class RecordingsViewModel {

    /// Newest first, or `nil` until the folder has been read.
    private(set) var recordings: [Recording]?

    /// The recordings' pictures, loaded as their tiles appear.
    private(set) var thumbnails: [URL: CGImage] = [:]

    /// Why the folder couldn't be read.
    private(set) var error: (any Error)?

    /// A tile's picture at most, in pixels: 16:9 at twice its width on screen.
    static let thumbnailSize = CGSize(width: 480, height: 270)

    private let folder: URL
    private let openEditor: (URL) -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "RecordingsViewModel")

    /// - Parameter openEditor: Opens a recording in the editor.
    init(folder: URL, openEditor: @escaping (URL) -> Void) {
        self.folder = folder
        self.openEditor = openEditor
    }

    /// Reads the folder again, e.g. when a recording was saved since.
    func reload() async {
        do {
            recordings = try await RecordingLibrary.recordings(in: folder)
            error = nil
        } catch {
            logger.error("Couldn't list \(self.folder.path): \(error.localizedDescription)")
            self.error = error
        }
    }

    func loadThumbnail(for recording: Recording) async {
        guard thumbnails[recording.url] == nil else { return }
        thumbnails[recording.url] = await ThumbnailProvider.thumbnail(of: recording.url, maximumSize: Self.thumbnailSize)
    }

    func open(_ recording: Recording) {
        openEditor(recording.url)
    }
}
