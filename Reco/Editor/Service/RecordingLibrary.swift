//
//  RecordingLibrary.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import Foundation
import UniformTypeIdentifiers

/// Lists the recordings in the output folder, off the main actor.
nonisolated enum RecordingLibrary {

    /// The videos in `folder`, newest first, without the editor's exports. A folder that doesn't
    /// exist yet has none.
    @concurrent
    static func recordings(in folder: URL) async throws -> [Recording] {
        let keys: [URLResourceKey] = [.contentTypeKey, .creationDateKey]
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: .skipsHiddenFiles)
        } catch CocoaError.fileReadNoSuchFile {
            return []
        }
        return urls.compactMap { url -> Recording? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.contentType?.conforms(to: .movie) == true,
                  !url.deletingPathExtension().lastPathComponent.hasSuffix(ExportFormat.nameSuffix) else {
                return nil
            }
            return Recording(url: url, date: values.creationDate ?? .distantPast)
        }
        .sorted { $0.date > $1.date }
    }
}
