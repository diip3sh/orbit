//
//  ExportFormat.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation

/// What an edited video can be exported as: codecs, each an `AVAssetExportSession` preset, and GIF.
nonisolated enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case hevc = "HEVC"
    case h264 = "H.264"
    case proRes422 = "ProRes 422"
    case proRes4444 = "ProRes 4444"
    case gif = "GIF"

    /// Added to the recording's name for its export.
    static let nameSuffix = "-edited"

    var id: Self { self }

    /// `nil` for GIF, which ``GIFWriter`` writes.
    var preset: String? {
        switch self {
        case .hevc: AVAssetExportPresetHEVCHighestQuality
        case .h264: AVAssetExportPresetHighestQuality
        case .proRes422: AVAssetExportPresetAppleProRes422LPCM
        case .proRes4444: AVAssetExportPresetAppleProRes4444LPCM
        case .gif: nil
        }
    }

    /// MP4, which plays everywhere, except for ProRes, which needs QuickTime's container. `nil` for GIF.
    var fileType: AVFileType? {
        switch self {
        case .hevc, .h264: .mp4
        case .proRes422, .proRes4444: .mov
        case .gif: nil
        }
    }

    private var fileExtension: String {
        switch self {
        case .hevc, .h264: "mp4"
        case .proRes422, .proRes4444: "mov"
        case .gif: "gif"
        }
    }

    /// Whether an HDR recording stays HDR; H.264 and GIF export it in SDR.
    var keepsHDR: Bool {
        self != .h264 && self != .gif
    }

    /// Whether a transparent background stays transparent; other formats export it black.
    var keepsTransparency: Bool {
        self == .proRes4444
    }

    /// `<name>-edited.<mp4|mov|gif>` next to the recording.
    func outputURL(for videoURL: URL) -> URL {
        let name = videoURL.deletingPathExtension().lastPathComponent + Self.nameSuffix
        return videoURL.deletingLastPathComponent().appending(path: name).appendingPathExtension(fileExtension)
    }
}
