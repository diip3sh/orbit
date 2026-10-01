//
//  ProjectStore.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// Reads and writes a recording's project file, off the main actor. The recording's folder must be
/// accessible, i.e. the output folder's security scope held.
nonisolated enum ProjectStore {

    /// The recording's saved project, or `nil` when it has none yet.
    @concurrent
    static func read(for videoURL: URL) async throws -> EditorProject? {
        let data: Data
        do {
            data = try Data(contentsOf: EditorProject.fileURL(for: videoURL))
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
        return try JSONDecoder().decode(EditorProject.self, from: data)
    }

    /// Writes atomically, so a crash mid-save never leaves a truncated file.
    @concurrent
    static func write(_ project: EditorProject, for videoURL: URL) async throws {
        let data = try JSONEncoder().encode(project)
        try data.write(to: EditorProject.fileURL(for: videoURL), options: .atomic)
    }
}
