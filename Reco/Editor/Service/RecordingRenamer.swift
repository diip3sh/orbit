//
//  RecordingRenamer.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation

/// Renames a recording on disk: the movie and the telemetry and project beside it. The recording's folder
/// must be accessible, i.e. the output folder's security scope held.
nonisolated enum RecordingRenamer {

    /// Moves the recording to `name` and returns the movie's new URL. All or nothing: when a move fails, the
    /// ones before it are undone.
    @concurrent
    static func rename(_ videoURL: URL, to name: String, fileManager: FileManager = .default) async throws -> URL {
        if let problem = RecordingRename.problem(with: name) {
            throw RenameError.invalidName(problem)
        }
        let moves = RecordingRename.moves(of: videoURL, to: name)
        let newVideo = moves[0].to
        // A name that differs only in case is the same file on a case-insensitive volume: that is a rename
        let isSameFile = newVideo.path().caseInsensitiveCompare(videoURL.path()) == .orderedSame
        if !isSameFile, fileManager.fileExists(atPath: newVideo.path()) {
            throw RenameError.nameTaken(newVideo.deletingPathExtension().lastPathComponent)
        }

        var done: [(from: URL, to: URL)] = []
        do {
            for move in moves where fileManager.fileExists(atPath: move.from.path()) {
                try fileManager.moveItem(at: move.from, to: move.to)
                done.append(move)
            }
        } catch {
            for move in done.reversed() {
                try? fileManager.moveItem(at: move.to, to: move.from)
            }
            throw error
        }
        return newVideo
    }

    enum RenameError: LocalizedError {
        case invalidName(String)
        case nameTaken(String)

        var errorDescription: String? {
            switch self {
            case .invalidName(let reason): reason
            case .nameTaken(let name): "A recording named \(name) already exists."
            }
        }
    }
}
