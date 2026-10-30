//
//  TranscriberTests.swift
//  RecoTests
//

import AVFoundation
import Speech
import Testing
@testable import Reco

// MARK: - Transcribing for real

/// Speech generated with `say`, a sentence at a time, placed at known times with silence between them, so where each
/// starts and ends is known to the sample.
@available(macOS 26, *)
private enum SpokenWords {

    static let sampleRate = 48_000.0

    /// The audio's start in the file, so a transcription has to keep the source timeline.
    static let audioStart = 1.0

    /// A sentence's words and where its sound is, in source seconds.
    struct Placed {
        let words: [String]
        let range: Range<Double>
    }

    /// Whether the model is there, so the test doesn't download one.
    static func modelIsInstalled(_ language: String) async -> Bool {
        await SpeechTranscriber.installedLocales.contains { $0.identifier == language }
    }

    /// `sentence`'s samples as `say` speaks it, without the silence around it, or `nil` if `say` didn't work.
    static func samples(of sentence: String, in folder: URL) throws -> [Int16]? {
        let url = folder.appending(path: "\(UUID().uuidString).aiff")
        let say = Process()
        say.executableURL = URL(filePath: "/usr/bin/say")
        say.arguments = ["-v", "Samantha", "--data-format=BEI16@48000", "-o", url.path(), sentence]
        try say.run()
        say.waitUntilExit()
        guard say.terminationStatus == 0 else { return nil }
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatInt16, interleaved: true)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let samples = UnsafeBufferPointer(start: buffer.int16ChannelData?[0], count: Int(buffer.frameLength))
        // Where the sound starts and ends: 2% of full scale, well over `say`'s silence
        let threshold = Int16(Double(Int16.max) * 0.02)
        guard let first = samples.firstIndex(where: { abs($0) > threshold }), let last = samples.lastIndex(where: { abs($0) > threshold }) else { return nil }
        return Array(samples[first...last])
    }

    /// `sentences` with `gap` seconds of silence around each, from ``audioStart``: the samples, and where each one is.
    static func spoken(_ sentences: [String], gap: Double, in folder: URL) throws -> (samples: [Int16], placed: [Placed])? {
        var samples = [Int16](repeating: 0, count: Int(gap * sampleRate))
        var placed: [Placed] = []
        for sentence in sentences {
            guard let spoken = try self.samples(of: sentence, in: folder) else { return nil }
            let start = audioStart + Double(samples.count) / sampleRate
            samples += spoken
            let words = sentence.split(separator: " ").map { normalized(String($0)) }
            placed.append(Placed(words: words, range: start..<audioStart + Double(samples.count) / sampleRate))
            samples += [Int16](repeating: 0, count: Int(gap * sampleRate))
        }
        return (samples, placed)
    }

    /// A word as compared: lowercase, letters only.
    static func normalized(_ word: String) -> String {
        word.lowercased().filter(\.isLetter)
    }

    /// A movie with two audio tracks as the recorder writes them: a tone first where the system audio would be, then
    /// the voice, starting at ``audioStart``. Returns the voice track's id.
    static func writeMovie(voice: [Int16], to url: URL) async throws -> CMPersistentTrackID {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: true))
        let tone = (0..<voice.count).map { Int16(8000 * sin(2 * .pi * 440 * Double($0) / sampleRate)) }
        let toneBuffer = try sampleBuffer(tone, format: format, at: audioStart)
        let voiceBuffer = try sampleBuffer(voice, format: format, at: audioStart)
        let inputs = [toneBuffer, voiceBuffer].map { AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: $0.formatDescription) }
        inputs.forEach(writer.add)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for (input, buffer) in zip(inputs, [toneBuffer, voiceBuffer]) {
            input.append(buffer)
            input.markAsFinished()
        }
        await writer.finishWriting()
        #expect(writer.status == .completed, "\(String(describing: writer.error))")
        let tracks = try await AVURLAsset(url: url).loadTracks(withMediaType: .audio)
        #expect(tracks.count == 2)
        return try #require(tracks.last).trackID
    }

    private static func sampleBuffer(_ samples: [Int16], format: AVAudioFormat, at time: Double) throws -> CMSampleBuffer {
        let pcm = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)))
        pcm.frameLength = AVAudioFrameCount(samples.count)
        let channel = try #require(pcm.int16ChannelData)[0]
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(sampleRate)),
            presentationTimeStamp: CMTime(seconds: time, preferredTimescale: CMTimeScale(sampleRate)),
            decodeTimeStamp: .invalid
        )
        var sampleSize = Int(format.streamDescription.pointee.mBytesPerFrame)
        var buffer: CMSampleBuffer?
        CMSampleBufferCreate(
            allocator: nil, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil, refcon: nil,
            formatDescription: format.formatDescription, sampleCount: CMItemCount(samples.count),
            sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize,
            sampleBufferOut: &buffer
        )
        let sampleBuffer = try #require(buffer)
        let status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, bufferList: pcm.audioBufferList
        )
        #expect(status == noErr)
        return sampleBuffer
    }
}

@MainActor
struct TranscriberTests {

    /// What can be known from `say` alone is where each sentence's sound starts and ends, from the samples. Starts come
    /// within 100 ms. Inside a sentence the model is looser: against `AVSpeechSynthesizer`'s own word markers on 40 words
    /// of continuous speech (2026-10-31, macOS 27.2), its starts were a median 112 ms off, 210 ms at p90, 322 ms at most.
    @Test func speechStartsWithin100msOfWhereSentencesStart() async throws {
        guard #available(macOS 26, *) else { return }
        guard await SpokenWords.modelIsInstalled("en_US") else {
            try Test.cancel("The en_US speech model isn't installed")
        }
        let folder = try temporaryFolder()
        let sentences = [
            "Please open the window before dinner tonight.",
            "The summer weather feels wonderful this evening.",
            "My brother wants to go hiking in the mountains.",
            "We should talk about the plans for the weekend."
        ]
        guard let (voice, placed) = try SpokenWords.spoken(sentences, gap: 2, in: folder) else {
            try Test.cancel("say couldn't speak with the Samantha voice")
        }
        let url = folder.appending(path: "speech.mov")
        let track = try await SpokenWords.writeMovie(voice: voice, to: url)

        let heard = try await Transcriber.transcribe(trackID: track, of: AVURLAsset(url: url), language: "en_US") { _ in }

        // The words each sentence's silence holds apart
        var report: [String] = []
        for sentence in placed {
            let words = heard.filter { $0.range.lowerBound >= sentence.range.lowerBound - 1 && $0.range.upperBound <= sentence.range.upperBound + 1 }
            let first = try #require(words.first, "Nothing heard at \(sentence.range)")
            let last = try #require(words.last)
            let startError = first.range.lowerBound - sentence.range.lowerBound
            let endError = last.range.upperBound - sentence.range.upperBound
            report.append("\(sentence.words[0]): start \(startError) end \(endError)")
            #expect(words.map { SpokenWords.normalized($0.text) } == sentence.words)
            #expect(abs(startError) <= 0.1, "\(sentence.words): started \(startError) off")
            // Ends are looser: measured up to 298 ms before the sound's end, which the model doesn't time as closely
            #expect(abs(endError) <= 0.35, "\(sentence.words): ended \(endError) off")
        }
        print("Transcriber timing:", report)
    }

    /// Cancelled before it starts and once it's under way.
    @Test func cancellingStopsIt() async throws {
        guard #available(macOS 26, *) else { return }
        guard await SpokenWords.modelIsInstalled("en_US") else {
            try Test.cancel("The en_US speech model isn't installed")
        }
        let folder = try temporaryFolder()
        guard let (voice, _) = try SpokenWords.spoken(["Please open the window before dinner tonight."], gap: 0.5, in: folder) else {
            try Test.cancel("say couldn't speak with the Samantha voice")
        }
        let url = folder.appending(path: "speech.mov")
        // Four minutes, which take seconds, so there's a while to cancel in
        let track = try await SpokenWords.writeMovie(voice: Array(repeating: voice, count: 60).flatMap(\.self), to: url)

        let early = Task {
            try await Transcriber.transcribe(trackID: track, of: AVURLAsset(url: url), language: "en_US") { _ in }
        }
        early.cancel()
        await #expect(throws: CancellationError.self) {
            _ = try await early.value
        }

        let started = AsyncStream<Void>.makeStream()
        let running = Task {
            try await Transcriber.transcribe(trackID: track, of: AVURLAsset(url: url), language: "en_US") { progress in
                if progress.fraction > 0 {
                    started.continuation.yield()
                }
            }
        }
        for await _ in started.stream {
            break
        }
        running.cancel()
        await #expect(throws: CancellationError.self) {
            _ = try await running.value
        }
    }

    @Test func silenceComesBackEmpty() async throws {
        guard #available(macOS 26, *) else { return }
        guard await SpokenWords.modelIsInstalled("en_US") else {
            try Test.cancel("The en_US speech model isn't installed")
        }
        let url = try temporaryFolder().appending(path: "silent.mov")
        let track = try await SpokenWords.writeMovie(voice: [Int16](repeating: 0, count: 96_000), to: url)
        let heard = try await Transcriber.transcribe(trackID: track, of: AVURLAsset(url: url), language: "en_US") { _ in }
        #expect(heard.isEmpty)
    }
}
