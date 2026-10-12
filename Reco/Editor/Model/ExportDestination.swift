//
//  ExportDestination.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation

/// Where an export is written.
nonisolated enum ExportDestination: Sendable {

    /// Next to the recording, where the Library lists it.
    case recordingFolder

    /// A temporary folder of its own, for the pasteboard to point at. It isn't deleted: a paste reads the file
    /// whenever it happens, and the system empties the temporary folder.
    case clipboard

    func outputURL(for videoURL: URL, format: ExportFormat) -> URL {
        let url = format.outputURL(for: videoURL)
        switch self {
        case .recordingFolder: return url
        case .clipboard: return URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: url.lastPathComponent)
        }
    }
}
