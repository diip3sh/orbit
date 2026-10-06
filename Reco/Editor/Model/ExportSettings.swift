//
//  ExportSettings.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import AVFoundation

/// How an edited video is exported: its format, quality, size and frame rate.
nonisolated struct ExportSettings: Equatable, Sendable {
    var format = ExportFormat.mp4
    var quality = ExportQuality.socialMedia

    /// The output's shorter side in pixels, or `nil` for the canvas's own.
    var resolution: Int?

    /// Frames per second, or `nil` for the recording's.
    var frameRate: Int?

    /// Whether the canvas has a transparent background, which only ProRes 4444 keeps.
    var transparentCanvas = false

    /// What the export page starts with: MP4, or ProRes for a transparent canvas, the only format that keeps it.
    static func initial(transparentCanvas: Bool) -> Self {
        ExportSettings(format: transparentCanvas ? .proRes : .mp4, transparentCanvas: transparentCanvas)
    }

    /// Whether an HDR recording stays HDR; a GIF is 8-bit SDR.
    var keepsHDR: Bool {
        format != .gif
    }

    /// Whether a transparent background stays transparent; other formats export it black.
    var keepsTransparency: Bool {
        format == .proRes && transparentCanvas
    }

    /// ProRes 4444 for a transparent canvas, else the 422 flavour of the quality.
    var proResCodec: AVVideoCodecType {
        transparentCanvas ? .proRes4444 : quality.proResCodec
    }

    // MARK: - Size

    /// The shorter sides the page offers, besides the canvas's own: 720p, 1080p and 4K.
    static let resolutions = [720, 1080, 2160]

    /// Only a size smaller than the canvas's own is available: nothing is scaled up.
    static func isAvailable(resolution: Int, below shorterSide: CGFloat) -> Bool {
        CGFloat(resolution) < shorterSide
    }

    // MARK: - Frame rate

    static let frameRates = [15, 30, 60]

    /// GIF stores each delay in whole centiseconds, and browsers slow delays under 2 cs down to 10 cs, so a
    /// 60 fps GIF (1 or 2 cs) plays at about 10 fps. 30 fps (3 cs) is the fastest that plays as made.
    static let gifMaximumFrameRate = 30

    /// The frame rate the file has: the chosen one or the recording's, and for a GIF at most 30.
    func outputFrameRate(recordingRate: Double) -> Double {
        let rate = frameRate.map(Double.init) ?? recordingRate
        return format == .gif ? min(rate, Double(Self.gifMaximumFrameRate)) : rate
    }

    /// Whether `value` is on offer: not above the recording's own rate, and for a GIF not above 30.
    func isAvailable(frameRate value: Int, recordingRate: Double) -> Bool {
        value <= Int(recordingRate.rounded()) && (format != .gif || value <= Self.gifMaximumFrameRate)
    }

    /// The offered rate the file has, or `nil` when it has none of them, e.g. a 24 fps recording.
    func selectedFrameRate(recordingRate: Double) -> Int? {
        let rate = Int(outputFrameRate(recordingRate: recordingRate).rounded())
        return Self.frameRates.contains(rate) ? rate : nil
    }

    /// Choosing the recording's own rate stores `nil`, so it follows the recording.
    mutating func choose(frameRate value: Int, recordingRate: Double) {
        frameRate = value == Int(recordingRate.rounded()) ? nil : value
    }

    // MARK: - Estimated size

    /// AAC's bitrate in an MP4.
    static let aacBitRate = 128_000.0

    /// 48 kHz, 16-bit stereo LPCM in a ProRes movie.
    static let pcmBitRate = 48_000.0 * 16 * 2

    /// ProRes' target rates are for this many pixels per second: 1920×1080 at 29.97 fps.
    private static let fullHDPixelsPerSecond = 1920.0 * 1080 * 29.97

    /// The video's average bitrate: what the encoder is told to reach for MP4, and ProRes' own target scaled to
    /// the size and rate. `nil` for a GIF, whose size depends on what is on screen.
    ///
    /// These are honest estimates only because the export encodes to that average: a preset gives no say over
    /// the bitrate, and a file whose size the encoder picks can't be known before it is written.
    func videoBitRate(size: CGSize, frameRate: Double) -> Double? {
        let pixelsPerSecond = Double(size.width * size.height) * frameRate
        switch format {
        case .mp4:
            return quality.hevcBitsPerPixel * pixelsPerSecond
        case .proRes:
            let megabits = transparentCanvas ? ExportQuality.proRes4444MegabitsAtFullHD : quality.proResMegabitsAtFullHD
            return megabits * 1_000_000 * pixelsPerSecond / Self.fullHDPixelsPerSecond
        case .gif:
            return nil
        }
    }

    /// The audio's bitrate, none for a GIF or a recording without audio.
    func audioBitRate(hasAudio: Bool) -> Double {
        guard hasAudio else { return 0 }
        return switch format {
        case .mp4: Self.aacBitRate
        case .proRes: Self.pcmBitRate
        case .gif: 0
        }
    }

    /// The file's size in bytes at that average bitrate, or `nil` for a GIF.
    func estimatedBytes(size: CGSize, frameRate: Double, duration: Double, hasAudio: Bool) -> Int64? {
        videoBitRate(size: size, frameRate: frameRate).map {
            Int64((($0 + audioBitRate(hasAudio: hasAudio)) * duration / 8).rounded())
        }
    }
}
