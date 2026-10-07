//
//  RecordingRename.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation

/// The rules for renaming a recording from the editor: which names are allowed, what the field shows, and
/// which files move. The Library tells kinds apart by file name alone, so a rename must not change the kind:
/// a web recording keeps its prefix (hidden in the field) and nothing may end like an export.
nonisolated enum RecordingRename {

    private static let maximumLength = 200

    /// What the name field shows: the movie's name, without a web recording's prefix.
    static func displayName(of videoURL: URL) -> String {
        let name = videoURL.deletingPathExtension().lastPathComponent
        return name.hasPrefix(LibraryItem.webRecordingPrefix) ? String(name.dropFirst(LibraryItem.webRecordingPrefix.count)) : name
    }

    /// Why `name` can't be used, worded for the window, or `nil` when it can.
    static func problem(with name: String) -> String? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "A name can't be empty."
        }
        if name.contains("/") || name.contains(":") {
            return "A name can't contain / or :."
        }
        if name.hasPrefix(".") {
            return "A name can't start with a dot."
        }
        if name.count > maximumLength {
            return "A name can be at most \(maximumLength) characters."
        }
        if name.hasSuffix(ExportFormat.nameSuffix) {
            return "Names ending in \(ExportFormat.nameSuffix) are kept for exports."
        }
        return nil
    }

    /// The movie and the files beside it that belong to it, each with where it goes under `name`.
    static func moves(of videoURL: URL, to name: String) -> [(from: URL, to: URL)] {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let isWeb = videoURL.deletingPathExtension().lastPathComponent.hasPrefix(LibraryItem.webRecordingPrefix)
        let newVideo = videoURL.deletingLastPathComponent()
            .appending(path: (isWeb ? LibraryItem.webRecordingPrefix : "") + name)
            .appendingPathExtension(videoURL.pathExtension)
        return [
            (videoURL, newVideo),
            (InputTelemetry.sidecarURL(for: videoURL), InputTelemetry.sidecarURL(for: newVideo)),
            (EditorProject.fileURL(for: videoURL), EditorProject.fileURL(for: newVideo))
        ]
    }
}
