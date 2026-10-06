//
//  LibraryItem.swift
//  Reco
//

import Foundation
import UniformTypeIdentifiers

/// Something Reco made, as the Library lists it (spec 0010): a screen or web recording or an edited
/// export in the recordings folder, or a screenshot in the screenshot folder.
nonisolated struct LibraryItem: Identifiable, Hashable, Sendable {

    enum Kind: Sendable {
        case recording
        case webRecording
        case export
        case screenshot
    }

    let url: URL
    let kind: Kind

    /// When it was saved.
    let date: Date

    var id: URL { url }

    var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    /// Whether it opens in the editor, rather than in the system's viewer: a GIF export is an image.
    var isMovie: Bool {
        kind != .screenshot && url.pathExtension != "gif"
    }

    /// The files that go with it: a recording's telemetry and editor project beside the movie. Moving
    /// it to the Trash takes them along, so nothing is left orphaned.
    var companions: [URL] {
        guard kind == .recording || kind == .webRecording else { return [] }
        return [InputTelemetry.sidecarURL(for: url), EditorProject.fileURL(for: url)]
    }

    /// What a file in the recordings folder is: movies only, and an export when the editor named it so, which
    /// may be a GIF too; a web recording by the name renders get.
    static func recordingKind(of url: URL, contentType: UTType?) -> Kind? {
        let name = url.deletingPathExtension().lastPathComponent
        let isExport = name.hasSuffix(ExportFormat.nameSuffix)
        guard contentType?.conforms(to: .movie) == true || (isExport && contentType?.conforms(to: .gif) == true) else { return nil }
        if isExport {
            return .export
        }
        return name.hasPrefix(webRecordingPrefix) ? .webRecording : .recording
    }

    /// Whether a file in the screenshot folder is one of Reco's: that folder is the Desktop by default,
    /// which holds everything else too.
    static func isScreenshot(_ url: URL, contentType: UTType?) -> Bool {
        contentType?.conforms(to: .png) == true && url.lastPathComponent.hasPrefix(screenshotPrefix)
    }

    /// The prefixes `SettingsStore.filename(prefix:fileExtension:date:)` is given for these.
    static let webRecordingPrefix = "Reco_Web_"
    static let screenshotPrefix = "Reco_Screenshot_"
}

/// A sidebar entry: everything, or one kind.
nonisolated enum LibrarySection: CaseIterable, Hashable, Sendable {
    case all
    case recordings
    case webRecordings
    case exports
    case screenshots

    func contains(_ item: LibraryItem) -> Bool {
        switch self {
        case .all: true
        case .recordings: item.kind == .recording
        case .webRecordings: item.kind == .webRecording
        case .exports: item.kind == .export
        case .screenshots: item.kind == .screenshot
        }
    }
}
