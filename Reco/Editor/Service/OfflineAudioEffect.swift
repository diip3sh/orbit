//
//  OfflineAudioEffect.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import AVFoundation

/// An offline `AVAudioEngine` that plays what an asset reader reads through one effect, a chunk at a time, and writes
/// what comes out of it on the source timeline: the time-pitch of ``SpeedAudio`` and the sound isolation of
/// ``VoiceEnhancer`` share it.
nonisolated final class OfflineAudioEffect {

    /// Frames rendered at a time.
    static let chunk: AVAudioFrameCount = 4096

    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    private let rendered: AVAudioPCMBuffer

    /// What is scheduled, read by the source node as the engine renders. Not an `AVAudioPlayerNode`: its schedules
    /// reach the render thread through a queue, and when the first render came before the first buffer did, every
    /// output was one render chunk late. Measured 2026-10-08 on 7 s of speech: 3 of 9 runs, whatever the chunk size.
    private let queue = SampleQueue()

    /// The effect's latency in output frames.
    let latency: Int

    /// The engine playing through `effect`, whose latency is `latency` seconds, or what it reports.
    init(format: AVAudioFormat, effect: AVAudioUnit, latency: Double? = nil) throws {
        let source = AVAudioSourceNode(format: format) { [queue] _, _, frameCount, buffers in
            queue.read(frameCount, into: buffers)
        }
        engine.attach(source)
        engine.attach(effect)
        engine.connect(source, to: effect, format: format)
        engine.connect(effect, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: Self.chunk)
        guard let rendered = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: Self.chunk) else { throw AVError(.unknown) }
        self.format = format
        self.rendered = rendered
        self.latency = Int(((latency ?? effect.latency) * format.sampleRate).rounded())
        try engine.start()
    }

    deinit {
        engine.stop()
    }

    /// Writes `frames` frames to `file`: what `output` reads from source time `start` on, through the effect at `rate`
    /// (output time is source time over the rate). Audio read before `start` is context, dropped on the way out; a
    /// start before the first sample is silence until it.
    func process(_ output: AVAssetReaderOutput, from start: Double, frames: Int, rate: Double, into file: AVAudioFile) throws {
        // Output frames before the start comes out: the context read before it, over the rate, and the effect's latency
        var skipped: Int?
        var scheduled = 0.0
        var produced = 0
        var written = 0
        var isRead = false
        while written < frames {
            try Task.checkCancellation()
            // Keep a chunk's worth of input ahead of what is rendered
            while !isRead, scheduled / rate < Double(produced + latency) + 2 * Double(Self.chunk) {
                guard let sample = output.copyNextSampleBuffer() else {
                    // Silence past the end, so the effect lets go of the last of the audio
                    try scheduleSilence(frames: AVAudioFrameCount((Double(latency) + 2 * Double(Self.chunk)) * rate))
                    isRead = true
                    break
                }
                if skipped == nil {
                    let lead = (start - CMSampleBufferGetPresentationTimeStamp(sample).seconds) * format.sampleRate
                    if lead < 0 {
                        try scheduleSilence(frames: AVAudioFrameCount(-lead.rounded()))
                        scheduled -= lead.rounded()
                    }
                    skipped = Int((max(lead, 0) / rate).rounded()) + latency
                }
                scheduled += Double(try schedule(sample))
            }
            let rendered = try render()
            let count = Int(rendered.frameLength)
            let from = min(max((skipped ?? 0) - produced, 0), count)
            let kept = min(count - from, frames - written)
            produced += count
            guard kept > 0 else { continue }
            try file.write(from: rendered.dropping(from, keeping: kept))
            written += kept
        }
    }

    // MARK: - Private

    /// Schedules `sample`'s audio and returns how many frames it holds.
    private func schedule(_ sample: CMSampleBuffer) throws -> Int {
        let count = CMSampleBufferGetNumSamples(sample)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { throw AVError(.unknown) }
        buffer.frameLength = AVAudioFrameCount(count)
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(count), into: buffer.mutableAudioBufferList)
        guard status == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        queue.append(buffer)
        return count
    }

    private func scheduleSilence(frames: AVAudioFrameCount) throws {
        guard frames > 0 else { return }
        guard let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let channels = silence.floatChannelData else {
            throw AVError(.unknown)
        }
        silence.frameLength = frames
        for channel in 0..<Int(format.channelCount) {
            channels[channel].update(repeating: 0, count: Int(frames))
        }
        queue.append(silence)
    }

    /// The next chunk, in a buffer reused by the next call.
    private func render() throws -> AVAudioPCMBuffer {
        guard try engine.renderOffline(Self.chunk, to: rendered) == .success else { throw AVError(.unknown) }
        return rendered
    }

    /// Buffers in the order they play, read from the front as the engine renders. Both ends run on the thread calling
    /// `renderOffline`, since the source node renders synchronously in manual rendering mode.
    private final class SampleQueue: @unchecked Sendable {
        private var buffers: [AVAudioPCMBuffer] = []

        /// Frames of the first buffer already played.
        private var offset = 0

        func append(_ buffer: AVAudioPCMBuffer) {
            buffers.append(buffer)
        }

        /// Fills `output` with the next `frameCount` frames, silence once the queue is empty.
        func read(_ frameCount: AVAudioFrameCount, into output: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
            let outputs = UnsafeMutableAudioBufferListPointer(output)
            var filled = 0
            while filled < Int(frameCount), let buffer = buffers.first, let channels = buffer.floatChannelData {
                let count = min(Int(buffer.frameLength) - offset, Int(frameCount) - filled)
                for (channel, destination) in outputs.enumerated() {
                    destination.mData?.assumingMemoryBound(to: Float.self).advanced(by: filled)
                        .update(from: channels[channel] + offset, count: count)
                }
                filled += count
                offset += count
                if offset == Int(buffer.frameLength) {
                    buffers.removeFirst()
                    offset = 0
                }
            }
            for destination in outputs {
                destination.mData?.assumingMemoryBound(to: Float.self).advanced(by: filled).update(repeating: 0, count: Int(frameCount) - filled)
            }
            return noErr
        }
    }
}

// MARK: - Reading and writing

nonisolated extension OfflineAudioEffect {

    /// An audio track of a file, with its format as the engine takes it: float, non-interleaved, at the track's rate
    /// and channels.
    struct Source {
        let asset: AVURLAsset
        let track: AVAssetTrack
        let format: AVAudioFormat
        let timeRange: CMTimeRange

        /// Track `trackID` of the file at `url`, or its first audio track when `nil`.
        init(_ trackID: CMPersistentTrackID?, of url: URL) async throws {
            let asset = AVURLAsset(url: url)
            let track = if let trackID { try await asset.loadTrack(withTrackID: trackID) } else { try await asset.loadTracks(withMediaType: .audio).first }
            guard let track, let description = try await track.load(.formatDescriptions).first,
                  let stream = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
                  let format = AVAudioFormat(standardFormatWithSampleRate: stream.mSampleRate, channels: stream.mChannelsPerFrame) else {
                throw AVError(.unknown)
            }
            self.asset = asset
            self.track = track
            self.format = format
            timeRange = try await track.load(.timeRange)
        }

        /// A reader of the track over `range`, started; its one output is `outputs[0]`.
        func reader(over range: CMTimeRange) throws -> AVAssetReader {
            let reader = try AVAssetReader(asset: asset)
            reader.timeRange = range
            reader.add(AVAssetReaderTrackOutput(track: track, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: true, AVLinearPCMIsBigEndianKey: false,
                AVSampleRateKey: format.sampleRate, AVNumberOfChannelsKey: format.channelCount
            ]))
            guard reader.startReading() else { throw reader.error ?? AVError(.unknown) }
            return reader
        }
    }

    /// Writes what `body` renders in `format` to `url` as Apple Lossless, removing the file if it fails.
    static func write(to url: URL, format: AVAudioFormat, _ body: (AVAudioFile) throws -> Void) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            let file = try AVAudioFile(
                forWriting: url,
                settings: [
                    AVFormatIDKey: kAudioFormatAppleLossless, AVSampleRateKey: format.sampleRate,
                    AVNumberOfChannelsKey: format.channelCount, AVEncoderBitDepthHintKey: 24
                ],
                commonFormat: .pcmFormatFloat32, interleaved: false
            )
            try body(file)
            file.close()
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }
}

nonisolated private extension AVAudioPCMBuffer {

    /// The buffer with its first `count` frames dropped and `kept` frames left, moved in place.
    func dropping(_ count: Int, keeping kept: Int) -> AVAudioPCMBuffer {
        if count > 0, let channels = floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                memmove(channels[channel], channels[channel] + count, kept * MemoryLayout<Float>.size)
            }
        }
        frameLength = AVAudioFrameCount(kept)
        return self
    }
}
