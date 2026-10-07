//
//  ClickSoundWriter.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import AVFoundation

/// Writes the click sounds of a recording as an audio file the composition can insert like the recording's own tracks.
nonisolated enum ClickSoundWriter {

    /// Where a window keeps its click sounds, until it closes.
    static var folder: URL {
        URL.temporaryDirectory.appending(path: "Reco Click Sounds")
    }

    /// Writes `frameCount` mono samples at ``ClickSound/sampleRate`` with a click at each of `onsets`, in a second at a
    /// time so a long recording isn't held in memory.
    ///
    /// Apple Lossless in a CAF file: it keeps each onset to the sample, where AAC would shift it by its priming, and
    /// the silence between clicks costs next to nothing.
    @concurrent
    static func write(onsets: [Int], frameCount: Int, to url: URL) async throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatAppleLossless, AVSampleRateKey: ClickSound.sampleRate, AVNumberOfChannelsKey: 1,
                AVEncoderBitDepthHintKey: 16
            ],
            commonFormat: .pcmFormatFloat32, interleaved: false
        )
        let chunk = Int(ClickSound.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(chunk)),
              let channel = buffer.floatChannelData?[0] else {
            throw AVError(.unknown)
        }

        var frame = 0
        while frame < frameCount {
            let count = min(chunk, frameCount - frame)
            let samples = UnsafeMutableBufferPointer(start: channel, count: count)
            samples.update(repeating: 0)
            ClickSound.mix(onsets: onsets, into: samples, startingAt: frame)
            buffer.frameLength = AVAudioFrameCount(count)
            try file.write(from: buffer)
            frame += count
        }
        file.close()
    }
}
