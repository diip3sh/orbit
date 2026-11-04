//
//  Transcriber.swift
//  Reco
//

import AVFoundation
import Foundation
import Speech

/// Turns a recording's voice into timed words, on the device (spec 0004, N5).
///
/// Reads the track with an asset reader, not `AVAudioFile`, which sees only a movie's first audio track: the system
/// audio when there are two. Each buffer carries its source time, so a track starting late stays in step.
@available(macOS 26, *)
nonisolated enum Transcriber {

    /// Why a recording couldn't be transcribed.
    enum Failure: LocalizedError {
        case unavailable
        case unsupportedLanguage
        case unreadableAudio

        var errorDescription: String? {
            switch self {
            case .unavailable: String(localized: "Speech transcription isn't available on this Mac.")
            case .unsupportedLanguage: String(localized: "This Mac can't transcribe that language.")
            case .unreadableAudio: String(localized: "The recording's audio couldn't be read.")
            }
        }
    }

    /// The locale identifiers that can be transcribed, sorted by what they're called in the current language.
    static func languages() async -> [String] {
        let identifiers = await SpeechTranscriber.supportedLocales.map(\.identifier)
        return identifiers.sorted { name(ofLanguage: $0).localizedStandardCompare(name(ofLanguage: $1)) == .orderedAscending }
    }

    /// The Mac's language among those that can be transcribed, or `nil` when it isn't one.
    static func preferredLanguage() async -> String? {
        await SpeechTranscriber.supportedLocale(equivalentTo: .current)?.identifier
    }

    static func name(ofLanguage identifier: String) -> String {
        Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    /// The words of audio track `trackID` in source seconds, installing the language's model first if it needs one.
    /// Each word's text starts with the space before it where the language has one, as ``CaptionSegmenter`` expects.
    /// Empty when no speech came back. Cancelling the calling task stops it, with a `CancellationError`, at any point.
    @concurrent
    static func transcribe(
        trackID: CMPersistentTrackID, of asset: AVURLAsset, language: String, progress: @escaping @MainActor @Sendable (CaptionProgress) -> Void
    ) async throws -> [CaptionWord] {
        guard SpeechTranscriber.isAvailable else { throw Failure.unavailable }
        let transcriber = SpeechTranscriber(
            locale: Locale(identifier: language), transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange, .transcriptionConfidence]
        )
        try await install(for: transcriber, progress: progress)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else { throw Failure.unsupportedLanguage }

        let duration = try await asset.load(.duration).seconds
        let (reader, output) = try await reader(of: trackID, in: asset, format: format)
        defer { reader.cancelReading() }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        await progress(.transcribing(0))
        // The reader outruns the analyzer, so what's waiting can reach the whole track: 115 MB for an hour at 16 kHz
        let (inputs, feed) = AsyncStream<AnalyzerInput>.makeStream()
        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: [CaptionWord].self) { group in
                group.addTask {
                    var words: [CaptionWord] = []
                    for try await result in transcriber.results {
                        append(result, to: &words)
                        if duration > 0 {
                            await progress(.transcribing(min(result.range.end.seconds / duration, 1)))
                        }
                    }
                    return words
                }
                do {
                    try await analyzer.start(inputSequence: inputs)
                    while let sample = output.copyNextSampleBuffer() {
                        try Task.checkCancellation()
                        feed.yield(try input(from: sample, format: format))
                    }
                    guard reader.status != .failed else { throw reader.error ?? Failure.unreadableAudio }
                    feed.finish()
                    try await analyzer.finalizeAndFinishThroughEndOfInput()
                } catch {
                    feed.finish()
                    await analyzer.cancelAndFinishNow()
                    group.cancelAll()
                    throw error
                }
                let words = try await group.next() ?? []
                try Task.checkCancellation()
                return words
            }
        } onCancel: {
            feed.finish()
            Task { await analyzer.cancelAndFinishNow() }
        }
    }

    /// A started reader of audio track `trackID` in `format`, the analyzer's, and its output.
    private static func reader(
        of trackID: CMPersistentTrackID, in asset: AVURLAsset, format: AVAudioFormat
    ) async throws -> (AVAssetReader, AVAssetReaderAudioMixOutput) {
        guard let track = try await asset.loadTrack(withTrackID: trackID) else { throw Failure.unreadableAudio }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: format.streamDescription.pointee.mBitsPerChannel,
            AVLinearPCMIsFloatKey: format.commonFormat == .pcmFormatFloat32 || format.commonFormat == .pcmFormatFloat64,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: !format.isInterleaved
        ])
        guard reader.canAdd(output) else { throw Failure.unreadableAudio }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? Failure.unreadableAudio }
        return (reader, output)
    }

    /// Downloads the model `transcriber` needs, if any, reporting how far it is. `AssetInventory` keeps it in system
    /// storage, shared between apps.
    ///
    /// Cancelling returns at once, but the system finishes the download regardless: measured 2026-10-31 on macOS 27.2,
    /// a request cancelled, along with its `progress`, 1.5 s in installed the model 20 s later. So the wait is on a
    /// stream that cancelling ends, not on the download itself. Its `progress` can sit at 0 until it's done.
    private static func install(for transcriber: SpeechTranscriber, progress: @escaping @MainActor @Sendable (CaptionProgress) -> Void) async throws {
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else { return }
        await progress(.installing(0))
        let watcher = Task {
            while !Task.isCancelled {
                await progress(.installing(request.progress.fractionCompleted))
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { watcher.cancel() }
        let (installed, finish) = AsyncThrowingStream<Void, any Error>.makeStream()
        Task {
            do {
                try await request.downloadAndInstall()
                finish.finish()
            } catch {
                finish.finish(throwing: error)
            }
        }
        for try await _ in installed {}
        try Task.checkCancellation()
    }

    /// `sample`'s audio for the analyzer, at its source time.
    private static func input(from sample: CMSampleBuffer, format: AVAudioFormat) throws -> AnalyzerInput {
        let count = CMSampleBufferGetNumSamples(sample)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { throw Failure.unreadableAudio }
        buffer.frameLength = AVAudioFrameCount(count)
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(count), into: buffer.mutableAudioBufferList)
        guard status == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        return AnalyzerInput(buffer: buffer, bufferStartTime: CMSampleBufferGetPresentationTimeStamp(sample))
    }

    /// Adds a final result's words. The analyzer's text is one run per word, the space before it included.
    private static func append(_ result: SpeechTranscriber.Result, to words: inout [CaptionWord]) {
        for run in result.text.runs {
            let time = run.audioTimeRange.map { $0.start.seconds..<max($0.start.seconds, $0.end.seconds) }
            CaptionSegmenter.append(text: String(result.text[run.range].characters), range: time, confidence: run.transcriptionConfidence, to: &words)
        }
    }
}
