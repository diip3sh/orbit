//
//  ExportQuality.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import AVFoundation

/// How hard an export is compressed: from the best for further editing to the smallest file.
nonisolated enum ExportQuality: CaseIterable, Identifiable, Sendable {
    case studio
    case socialMedia
    case web
    case webLow

    var id: Self { self }

    /// HEVC's target average bitrate per pixel per frame, as the recorder's `VideoQuality` does.
    var hevcBitsPerPixel: Double {
        switch self {
        case .studio: 0.20
        case .socialMedia: 0.10
        case .web: 0.05
        case .webLow: 0.025
        }
    }

    /// The ProRes 422 flavour: the lower the quality, the lighter the flavour.
    var proResCodec: AVVideoCodecType {
        switch self {
        case .studio: .proRes422HQ
        case .socialMedia: .proRes422
        case .web: .proRes422LT
        case .webLow: .proRes422Proxy
        }
    }

    /// The flavour's target data rate in Mbit/s at 1920×1080 and 29.97 fps, from Apple's ProRes white paper.
    var proResMegabitsAtFullHD: Double {
        switch self {
        case .studio: 220
        case .socialMedia: 147
        case .web: 102
        case .webLow: 45
        }
    }

    /// ProRes 4444's, which is the only flavour that keeps transparency and so has no levels.
    static let proRes4444MegabitsAtFullHD = 330.0
}
