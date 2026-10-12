//
//  SoundCache.swift
//  Reco
//

import AVFoundation
import CryptoKit

/// Where a bundle keeps its sound (spec 0013): `assets/sound/<key>.caf`, Apple Lossless, the key hashing
/// the cue sheet, so an edit that moves no cue plays the sound already made and one that does makes it again.
nonisolated enum SoundCache {

    /// Changes when the same sheet would sound different, so bundles make theirs again.
    static let soundVersion = 2

    /// The sounds a bundle keeps, the most recently used: the preview's, an export's at another frame rate,
    /// and the one before an edit; older ones are deleted.
    static let kept = 3

    static func url(of sheet: SoundCueSheet, in bundle: URL) -> URL {
        bundle.appending(path: "assets/sound/\(key(of: sheet)).caf")
    }

    /// The file holding `sheet`'s sound, made the first time it's asked for; `nil` for a silent sheet.
    @concurrent
    static func sound(for sheet: SoundCueSheet, in bundle: URL) async throws -> URL? {
        guard !sheet.isSilent else { return nil }
        let url = url(of: sheet, in: bundle)
        let manager = FileManager.default
        if manager.fileExists(atPath: url.path(percentEncoded: false)) {
            try? manager.setAttributes([.modificationDate: Date.now], ofItemAtPath: url.path(percentEncoded: false))
            return url
        }
        let sound = ScoreRenderer.render(sheet)
        try Task.checkCancellation()
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Written beside it and moved into place, so a build reading it never sees half a file
        let partial = url.deletingLastPathComponent().appending(path: "\(UUID().uuidString).partial.caf")
        defer { try? manager.removeItem(at: partial) }
        try write(sound, to: partial)
        do {
            try manager.moveItem(at: partial, to: url)
        } catch _ where manager.fileExists(atPath: url.path(percentEncoded: false)) {
            // Another build made the same sound meanwhile
        }
        prune(url.deletingLastPathComponent())
        return url
    }

    /// Writes `sound` as 24-bit Apple Lossless.
    static func write(_ sound: StereoSound, to url: URL) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: SoundSignal.sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sound.count)),
              let channels = buffer.floatChannelData else { throw CocoaError(.fileWriteUnknown) }
        buffer.frameLength = AVAudioFrameCount(sound.count)
        for (index, channel) in [sound.left, sound.right].enumerated() {
            channel.withUnsafeBufferPointer { samples in
                guard let start = samples.baseAddress else { return }
                channels[index].update(from: start, count: samples.count)
            }
        }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatAppleLossless, AVSampleRateKey: SoundSignal.sampleRate, AVNumberOfChannelsKey: 2, AVEncoderBitDepthHintKey: 24
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
    }

    /// The integrated loudness of the sound in `url`, in LUFS.
    @concurrent
    static func loudness(of url: URL) async throws -> Double {
        Loudness.integrated(try read(url))
    }

    /// The sound in `url`, as written.
    static func read(_ url: URL) throws -> StereoSound {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw CocoaError(.fileReadUnknown)
        }
        try file.read(into: buffer)
        guard let channels = buffer.floatChannelData, buffer.format.channelCount == 2 else { throw CocoaError(.fileReadCorruptFile) }
        let count = Int(buffer.frameLength)
        return StereoSound(left: Array(UnsafeBufferPointer(start: channels[0], count: count)), right: Array(UnsafeBufferPointer(start: channels[1], count: count)))
    }

    private static func key(of sheet: SoundCueSheet) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(sheet)) ?? Data()
        return SHA256.hash(data: data + Data("\nsound \(soundVersion)".utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// Deletes all but the ``kept`` most recently used sounds in `folder`.
    private static func prune(_ folder: URL) {
        let manager = FileManager.default
        let files = (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let dated = files.filter { $0.pathExtension == "caf" && !$0.lastPathComponent.hasSuffix(".partial.caf") }.map { url in
            (url, (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
        }
        for (url, _) in dated.sorted(by: { $0.1 > $1.1 }).dropFirst(kept) {
            try? manager.removeItem(at: url)
        }
    }
}
