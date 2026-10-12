//
//  ExportFormat.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// The files an edited video can be exported as: MP4 (HEVC), a ProRes movie, or an animated GIF.
nonisolated enum ExportFormat: CaseIterable, Identifiable, Sendable {
    case mp4
    case proRes
    case gif

    /// Added to the recording's name for its export.
    static let nameSuffix = "-edited"

    var id: Self { self }

    var fileExtension: String {
        switch self {
        case .mp4: "mp4"
        case .proRes: "mov"
        case .gif: "gif"
        }
    }

    /// `<name>-edited.<mp4|mov|gif>` next to the recording.
    func outputURL(for videoURL: URL) -> URL {
        let name = videoURL.deletingPathExtension().lastPathComponent + Self.nameSuffix
        return videoURL.deletingLastPathComponent().appending(path: name).appendingPathExtension(fileExtension)
    }
}
