//
//  RecordingImporter.swift
//  Reco
//

import AVFoundation
import UniformTypeIdentifiers

/// Brings a video from elsewhere into the recordings folder (spec 0023, section 4), so its project has a writable home
/// beside it, the Library lists it and the original stays untouched. On the same volume the copy is a clone, which costs
/// nothing.
nonisolated enum RecordingImporter {

    enum ImportError: LocalizedError {
        case noVideo(String)

        var errorDescription: String? {
            switch self {
            case .noVideo(let name): "\(name) has no video Orbit can play."
            }
        }
    }

    /// Whether `url` is named like a movie.
    static func isMovie(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true
    }

    /// The copy of `file` in `folder` under a free name, listed as just made, or `file` itself when it's in `folder` already.
    /// Throws ``ImportError`` and copies nothing when it has no playable video.
    @concurrent
    static func importMovie(at file: URL, into folder: URL, fileManager: FileManager = .default) async throws -> URL {
        let tracks = try? await AVURLAsset(url: file).loadTracks(withMediaType: .video)
        guard tracks?.isEmpty == false else {
            throw ImportError.noVideo(file.lastPathComponent)
        }
        let isInFolder = file.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
            == folder.resolvingSymlinksInPath().standardizedFileURL
        guard !isInFolder else { return file }

        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = try freeName(for: file, among: fileManager.contentsOfDirectory(atPath: folder.path(percentEncoded: false)))
        let copy = folder.appending(path: name)
        try fileManager.copyItem(at: file, to: copy)
        // A copy keeps the original's date, which would list it far down a Library sorted by date
        try? fileManager.setAttributes([.creationDate: Date.now], ofItemAtPath: copy.path(percentEncoded: false))
        return copy
    }

    /// `file`'s name, numbered until nothing in the folder has that base name: a recording's companions are found by it, so
    /// `a.mp4` would otherwise share `a.edit.json` with `a.mov`. Without the suffixes that would list it as an export or
    /// hide it as camera footage.
    static func freeName(for file: URL, among names: [String]) -> String {
        var base = file.deletingPathExtension().lastPathComponent
        for suffix in [CameraFootage.nameSuffix, ExportFormat.nameSuffix] where base.hasSuffix(suffix) {
            base.removeLast(suffix.count)
        }
        let taken = names.map { $0.lowercased() }
        var candidate = base
        var number = 1
        while taken.contains(where: { $0.hasPrefix(candidate.lowercased() + ".") }) {
            number += 1
            candidate = "\(base) \(number)"
        }
        return "\(candidate).\(file.pathExtension)"
    }
}
