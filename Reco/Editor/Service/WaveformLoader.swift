//
//  WaveformLoader.swift
//  Reco
//

import AVFoundation

/// Reads the recording's audio once and reduces it to peak amplitudes for the timeline's waveform.
/// The mix of every track, so the picture matches what plays; volumes and mutes don't redraw it.
nonisolated enum WaveformLoader {

    /// Buckets per second of recording: at the deepest zoom (16×) a bucket is still under a point wide
    /// on any sane window (a 10-minute take has 12,000 buckets, 48 KB of floats).
    static let bucketsPerSecond = 20

    /// The reader's format: mono float at 8 kHz, plenty for peaks and 80× cheaper than the source's
    /// 48 kHz stereo (10 minutes read in about a second, like the speed audio renders).
    private static let sampleRate = 8000

    /// Peak amplitude per bucket, normalized to 0...1, for `source`'s whole length. Empty when the
    /// recording has no audio or it can't be read: the lane is simply left out.
    static func peaks(of source: EditorSource, bucketsPerSecond: Int) async -> [Float] {
        let tracks = (try? await source.asset.loadTracks(withMediaType: .audio)) ?? []
        let duration = source.duration
        guard !tracks.isEmpty, duration > 0, bucketsPerSecond > 0 else { return [] }

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: source.asset)
        } catch {
            return []
        }
        let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        guard reader.canAdd(output) else { return [] }
        reader.add(output)
        guard reader.startReading() else { return [] }

        var peaks = [Float](repeating: 0, count: Int((duration * Double(bucketsPerSecond)).rounded(.up)))
        while let buffer = output.copyNextSampleBuffer() {
            if Task.isCancelled {
                reader.cancelReading()
                return []
            }
            read(buffer, into: &peaks, buckets: peaks.count, duration: duration)
        }

        let loudest = peaks.max() ?? 0
        guard loudest > 0 else { return peaks }
        return peaks.map { $0 / loudest }
    }

    /// The reader's output as an `AVAudioPCMBuffer` format, for copying each buffer's samples out.
    private static let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: 1, interleaved: false)!

    /// Folds one buffer's samples into their buckets' peaks. Samples are the float mono the reader
    /// was asked for above.
    private static func read(_ buffer: CMSampleBuffer, into peaks: inout [Float], buckets: Int, duration: Double) {
        let count = CMSampleBufferGetNumSamples(buffer)
        guard count > 0, let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let samples = pcm.floatChannelData?[0] else { return }
        pcm.frameLength = AVAudioFrameCount(count)
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(buffer, at: 0, frameCount: Int32(count), into: pcm.mutableAudioBufferList) == noErr else {
            return
        }
        let start = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
        guard start.isFinite else { return }
        for index in 0..<count {
            let time = start + Double(index) / Double(sampleRate)
            let bucket = Int(time / duration * Double(buckets))
            guard bucket >= 0, bucket < buckets else { continue }
            peaks[bucket] = max(peaks[bucket], abs(samples[index]))
        }
    }
}
