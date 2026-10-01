//
//  AssetWriterSettings.swift
//  Reco
//

import AVFoundation
import CoreVideo
import Foundation
import OSLog
import VideoToolbox

/// Builds the `AVAssetWriterInput` output settings for a recording.
enum AssetWriterSettings {

    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "AssetWriter")

    /// Builds the video output settings for the selected codec, quality and dynamic range.
    static func video(from settings: SettingsStore, size: CGSize) -> [String: Any] {
        var videoSettings: [String: Any] = [
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]

        let hdrPreset = settings.hdrPreset

        switch settings.videoCodec {
        case .h264:
            videoSettings[AVVideoCodecKey] = AVVideoCodecType.h264

        case .hevc:
            if settings.captureAlphaChannel {
                videoSettings[AVVideoCodecKey] = AVVideoCodecType.hevcWithAlpha
            } else {
                videoSettings[AVVideoCodecKey] = AVVideoCodecType.hevc
            }

        case .proRes422:
            videoSettings[AVVideoCodecKey] = AVVideoCodecType.proRes422

        case .proRes4444:
            videoSettings[AVVideoCodecKey] = AVVideoCodecType.proRes4444
        }

        // Add compression properties for H.264 and HEVC to control bitrate.
        // ProRes codecs use fixed-quality encoding and don't need these.
        if let bpp = settings.videoQuality.bitsPerPixel(for: settings.videoCodec) {
            let frameRate = settings.frameRate.effectiveFrameRate
            let bitrate = Int(size.width * size.height * bpp * frameRate)

            var compressionProperties: [String: Any] = [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoMaxKeyFrameIntervalKey: Int(frameRate * 2)
            ]

            // HEVC HDR: enforce Main 10 profile to prevent 8-bit fallback and
            // enable automatic HDR metadata insertion (HDR10 / Dolby Vision).
            if settings.videoCodec == .hevc && hdrPreset != .sdr {
                compressionProperties[AVVideoProfileLevelKey] =
                    kVTProfileLevel_HEVC_Main10_AutoLevel as String
                compressionProperties[kVTCompressionPropertyKey_HDRMetadataInsertionMode as String] =
                    kVTHDRMetadataInsertionMode_Auto as String
            }

            videoSettings[AVVideoCompressionPropertiesKey] = compressionProperties

            logger.info(
                "Video compression: \(bitrate / 1_000_000) Mbps at \(Int(frameRate)) fps (\(settings.videoQuality.rawValue) quality)"
            )
        }

        // Color space tagging strategy differs by codec:
        //
        // HEVC HDR: Tag via AVVideoColorPropertiesKey with BT.2020 / PQ.
        //   The encoder writes the correct 'colr' atom and VUI parameters.
        //
        // ProRes HDR: Do NOT set AVVideoColorPropertiesKey. AVAssetWriter
        //   prohibits automatic color matching for the high-bit-depth pixel
        //   formats ProRes uses. Instead, BT.2020 / PQ colorimetry is
        //   injected per-frame via CVBufferSetAttachment in appendVideoSample().
        //
        // SDR (all codecs): Tag with Rec. 709 to ensure 'colr' atoms and
        //   VUI parameters are written.
        let isProRes = settings.videoCodec == .proRes422 || settings.videoCodec == .proRes4444

        if isProRes && hdrPreset != .sdr {
            // Color properties are tagged per-frame via CVBufferSetAttachment.
        } else if hdrPreset != .sdr {
            videoSettings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_SMPTE_ST_2084_PQ,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020
            ]
        } else {
            videoSettings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        }

        return videoSettings
    }

    /// Builds the audio output settings shared by the system audio and microphone tracks.
    static func audio(from settings: SettingsStore) -> [String: Any] {
        switch settings.audioCodec {
        case .aac:
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 256000
            ]

        case .pcm:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        }
    }

    /// Logs the pixel format, color space, and matrix of an incoming pixel buffer
    /// to help diagnose HDR color mismatches.
    nonisolated static func logPixelBufferProperties(_ pixelBuffer: CVPixelBuffer) {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let fourCC = String(format: "%c%c%c%c",
                            (pixelFormat >> 24) & 0xFF,
                            (pixelFormat >> 16) & 0xFF,
                            (pixelFormat >> 8) & 0xFF,
                            pixelFormat & 0xFF)

        let primaries = CVBufferCopyAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, nil)
            as? String ?? "none"
        let transfer = CVBufferCopyAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, nil)
            as? String ?? "none"
        let matrix = CVBufferCopyAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, nil)
            as? String ?? "none"

        let colorSpaceName: String
        if let cgColorSpace = CVImageBufferGetColorSpace(pixelBuffer)?.takeUnretainedValue() {
            colorSpaceName = cgColorSpace.name as String? ?? "unnamed"
        } else {
            colorSpaceName = "nil"
        }

        logger.info(
            """
            First frame buffer properties — \
            pixelFormat: \(fourCC) (0x\(String(pixelFormat, radix: 16))), \
            colorPrimaries: \(primaries), \
            transferFunction: \(transfer), \
            yCbCrMatrix: \(matrix), \
            CGColorSpace: \(colorSpaceName)
            """
        )
    }
}
