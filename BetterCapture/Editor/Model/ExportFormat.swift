//
//  ExportFormat.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation

/// The codecs an edited video can be exported with, each an `AVAssetExportSession` preset.
nonisolated enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case hevc = "HEVC"
    case h264 = "H.264"
    case proRes422 = "ProRes 422"

    var id: Self { self }

    var preset: String {
        switch self {
        case .hevc: AVAssetExportPresetHEVCHighestQuality
        case .h264: AVAssetExportPresetHighestQuality
        case .proRes422: AVAssetExportPresetAppleProRes422LPCM
        }
    }

    /// MP4, which plays everywhere, except for ProRes, which needs QuickTime's container.
    var fileType: AVFileType {
        self == .proRes422 ? .mov : .mp4
    }

    /// `<name>-edited.<mp4|mov>` next to the recording.
    func outputURL(for videoURL: URL) -> URL {
        let name = "\(videoURL.deletingPathExtension().lastPathComponent)-edited"
        return videoURL.deletingLastPathComponent().appending(path: name).appendingPathExtension(self == .proRes422 ? "mov" : "mp4")
    }
}
