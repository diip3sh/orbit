//
//  DynamicRange.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import AVFoundation

/// How a video encodes brightness: SDR, or HDR with the PQ or HLG transfer function.
nonisolated enum DynamicRange: Sendable {
    case sdr
    // swiftlint:disable:next identifier_name - the transfer function's name, like HLG's
    case pq
    case hlg

    /// The dynamic range a video track's format declares with its transfer function.
    init(of formatDescription: CMFormatDescription?) {
        let transferFunction = formatDescription.flatMap {
            CMFormatDescriptionGetExtension($0, extensionKey: kCMFormatDescriptionExtension_TransferFunction)
        } as? String
        switch transferFunction {
        case String(kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ): self = .pq
        case String(kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG): self = .hlg
        default: self = .sdr
        }
    }

    /// The video composition's transfer function; `nil` for SDR, which keeps the recording's tags.
    var transferFunction: String? {
        switch self {
        case .sdr: nil
        case .pq: AVVideoTransferFunction_SMPTE_ST_2084_PQ
        case .hlg: AVVideoTransferFunction_ITU_R_2100_HLG
        }
    }

    /// The color space HDR overlays are drawn in, the video's; `nil` for SDR, where they're drawn as they are.
    var colorSpace: CGColorSpace? {
        switch self {
        case .sdr: nil
        case .pq: CGColorSpace(name: CGColorSpace.itur_2100_PQ)
        case .hlg: CGColorSpace(name: CGColorSpace.itur_2100_HLG)
        }
    }
}
