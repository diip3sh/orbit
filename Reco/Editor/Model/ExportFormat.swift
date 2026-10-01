//
//  ExportFormat.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation

/// The codecs an edited video can be exported with, each an `AVAssetExportSession` preset.
nonisolated enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case hevc = "HEVC"
    case h264 = "H.264"
    case proRes422 = "ProRes 422"
    case proRes4444 = "ProRes 4444"

    /// Added to the recording's name for its export.
    static let nameSuffix = "-edited"

    var id: Self { self }

    var preset: String {
        switch self {
        case .hevc: AVAssetExportPresetHEVCHighestQuality
        case .h264: AVAssetExportPresetHighestQuality
        case .proRes422: AVAssetExportPresetAppleProRes422LPCM
        case .proRes4444: AVAssetExportPresetAppleProRes4444LPCM
        }
    }

    /// MP4, which plays everywhere, except for ProRes, which needs QuickTime's container.
    var fileType: AVFileType {
        switch self {
        case .hevc, .h264: .mp4
        case .proRes422, .proRes4444: .mov
        }
    }

    /// Whether an HDR recording stays HDR; H.264 exports it in SDR.
    var keepsHDR: Bool {
        self != .h264
    }

    /// Whether a transparent background stays transparent; other formats export it black.
    var keepsTransparency: Bool {
        self == .proRes4444
    }

    /// `<name>-edited.<mp4|mov>` next to the recording.
    func outputURL(for videoURL: URL) -> URL {
        let name = videoURL.deletingPathExtension().lastPathComponent + Self.nameSuffix
        return videoURL.deletingLastPathComponent().appending(path: name).appendingPathExtension(fileType == .mov ? "mov" : "mp4")
    }
}
