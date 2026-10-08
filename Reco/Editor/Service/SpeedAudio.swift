//
//  SpeedAudio.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import AVFoundation

/// The audio of the parts at another speed, sped up with its pitch kept, as files the composition inserts as they are.
///
/// The composition can't scale its audio itself: `AVAssetReaderAudioMixOutput`, which the export reads the mix through,
/// applies a scaled edit's rate change only after it has converted past it ("scheduling rate change at unscaled t=9600,
/// but we previously did a conversion for t=13056"), with every pitch algorithm. Measured 2026-10-08: a second of audio
/// with 0.2–0.6 s at 4× (0.7 s of output) mixed to 0.709–0.808 s across runs, and exported at 0.775 s.
nonisolated enum SpeedAudio {

    /// One track's part at one rate, which names its file.
    struct Part: Hashable, Sendable {
        /// The composition's ID for the track: the recording's own, or the click sounds'.
        let trackID: CMPersistentTrackID

        /// Source seconds, as in ``TimeMap/pieces``.
        let range: Range<Double>

        let rate: Double
    }

    /// Where a window keeps its sped-up audio, until it closes.
    static var folder: URL {
        URL.temporaryDirectory.appending(path: "Reco Speed Audio")
    }

    /// Audio read past each end of a part, so the time-pitch overlaps real sound there and the part meets its
    /// neighbours without a dip.
    static let context = 0.25

    /// Frames rendered at a time.
    private static let chunk: AVAudioFrameCount = 4096

    /// The parts of `timeMap` not at 1×, for each of `trackIDs`.
    static func parts(of timeMap: TimeMap, trackIDs: [CMPersistentTrackID]) -> [Part] {
        let pieces = timeMap.pieces.filter { $0.rate != 1 }
        return trackIDs.flatMap { trackID in pieces.map { Part(trackID: trackID, range: $0.range, rate: $0.rate) } }
    }

    /// Writes `part` of the audio track `trackID` (the first one when `nil`) of the file at `source`, on the source
    /// timeline, sped up to `url`: its length over its rate, rounded up to a whole frame, in Apple Lossless.
    @concurrent
    static func render(_ part: Part, from source: URL, trackID: CMPersistentTrackID?, to url: URL) async throws {
        let asset = AVURLAsset(url: source)
        let track = if let trackID { try await asset.loadTrack(withTrackID: trackID) } else { try await asset.loadTracks(withMediaType: .audio).first }
        guard let track, let description = try await track.load(.formatDescriptions).first,
              let stream = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
              let format = AVAudioFormat(standardFormatWithSampleRate: stream.mSampleRate, channels: stream.mChannelsPerFrame) else {
            throw AVError(.unknown)
        }
        let trackRange = try await track.load(.timeRange)
        let reader = try AVAssetReader(asset: asset)
        let timescale = CMTimeScale(format.sampleRate)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: max(part.range.lowerBound - context, trackRange.start.seconds), preferredTimescale: timescale),
            end: CMTime(seconds: min(part.range.upperBound + context, trackRange.end.seconds), preferredTimescale: timescale)
        )
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: true, AVLinearPCMIsBigEndianKey: false,
            AVSampleRateKey: format.sampleRate, AVNumberOfChannelsKey: format.channelCount
        ])
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? AVError(.unknown) }
        defer { reader.cancelReading() }

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
            try stretch(output, format: format, part: part, into: file)
            file.close()
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    /// Runs what `output` reads through a time-pitch at `part`'s rate and writes the part's length over its rate to
    /// `file`, from where the part's start comes out.
    private static func stretch(_ output: AVAssetReaderTrackOutput, format: AVAudioFormat, part: Part, into file: AVAudioFile) throws {
        let frames = Int(((part.range.upperBound - part.range.lowerBound) / part.rate * format.sampleRate).rounded(.up))
        let stretcher = try Stretcher(format: format, rate: part.rate)
        // Output frames before the part comes out: the context read before it, sped up, and the time-pitch's latency
        var skipped: Int?
        var scheduled = 0.0
        var produced = 0
        var written = 0
        var isRead = false
        while written < frames {
            try Task.checkCancellation()
            // Keep a chunk's worth of input ahead of what is rendered
            while !isRead, scheduled / part.rate < Double(produced + stretcher.latency) + 2 * Double(chunk) {
                guard let sample = output.copyNextSampleBuffer() else {
                    // Silence past the end, so the time-pitch lets go of the last of the part
                    try stretcher.scheduleSilence(frames: AVAudioFrameCount((Double(stretcher.latency) + 2 * Double(chunk)) * part.rate))
                    isRead = true
                    break
                }
                if skipped == nil {
                    let first = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                    skipped = Int(((part.range.lowerBound - first) * format.sampleRate / part.rate).rounded()) + stretcher.latency
                }
                scheduled += Double(try stretcher.schedule(sample))
            }
            let rendered = try stretcher.render()
            let count = Int(rendered.frameLength)
            let from = min(max((skipped ?? 0) - produced, 0), count)
            let kept = min(count - from, frames - written)
            produced += count
            guard kept > 0 else { continue }
            try file.write(from: rendered.dropping(from, keeping: kept))
            written += kept
        }
    }

    /// An offline engine that plays what is scheduled through a time-pitch, a chunk at a time.
    nonisolated private final class Stretcher {
        private let engine = AVAudioEngine()
        private let player = AVAudioPlayerNode()
        private let format: AVAudioFormat
        private let rendered: AVAudioPCMBuffer

        /// The time-pitch's latency in output frames.
        let latency: Int

        init(format: AVAudioFormat, rate: Double) throws {
            let timePitch = AVAudioUnitTimePitch()
            timePitch.rate = Float(rate)
            engine.attach(player)
            engine.attach(timePitch)
            engine.connect(player, to: timePitch, format: format)
            engine.connect(timePitch, to: engine.mainMixerNode, format: format)
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: chunk)
            guard let rendered = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: chunk) else { throw AVError(.unknown) }
            self.format = format
            self.rendered = rendered
            latency = Int((timePitch.latency * format.sampleRate).rounded())
            try engine.start()
            player.play()
        }

        deinit {
            engine.stop()
        }

        /// Schedules `sample`'s audio and returns how many frames it holds.
        func schedule(_ sample: CMSampleBuffer) throws -> Int {
            let count = CMSampleBufferGetNumSamples(sample)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { throw AVError(.unknown) }
            buffer.frameLength = AVAudioFrameCount(count)
            let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(count), into: buffer.mutableAudioBufferList)
            guard status == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
            player.scheduleBuffer(buffer)
            return count
        }

        func scheduleSilence(frames: AVAudioFrameCount) throws {
            guard let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let channels = silence.floatChannelData else {
                throw AVError(.unknown)
            }
            silence.frameLength = frames
            for channel in 0..<Int(format.channelCount) {
                channels[channel].update(repeating: 0, count: Int(frames))
            }
            player.scheduleBuffer(silence)
        }

        /// The next chunk, in a buffer reused by the next call.
        func render() throws -> AVAudioPCMBuffer {
            guard try engine.renderOffline(chunk, to: rendered) == .success else { throw AVError(.unknown) }
            return rendered
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
