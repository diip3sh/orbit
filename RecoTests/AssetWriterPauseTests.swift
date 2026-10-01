//
//  AssetWriterPauseTests.swift
//  RecoTests
//
//  Created by Diip3sh on 25.09.26.
//

import AVFoundation
import Testing
@testable import Reco

/// Pausing keeps the capture running and drops every sample until resume, cutting the paused
/// time from the file. Sample timestamps here start at zero rather than on the host clock, so
/// pause and resume are given explicit times.
extension AssetWriterTests {

    /// The grid continues where it was paused, so no frames are filled across a pause.
    @Test func pausesAreCutFromTheVideoWithoutFillingThem() async throws {
        let settings = makeStore()
        settings.frameRate = .fps30

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        // 6 s of frames, paused from 1 s to 2 s and from 3 s to 5 s
        for index in 0..<180 {
            switch index {
            case 30: assetWriter.pause(at: seconds(1))
            case 60: assetWriter.resume(at: seconds(2))
            case 90: assetWriter.pause(at: seconds(3))
            case 150: assetWriter.resume(at: seconds(5))
            default: break
            }
            assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: CMTime(value: CMTimeValue(index), timescale: 30)))
        }

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        // The 3 s recorded outside the pauses, on an unbroken grid
        let times = try await videoPresentationTimes(of: result.url)
        #expect(times == (0..<90).map { CMTime(value: CMTimeValue($0), timescale: 30) })
    }

    /// ScreenCaptureKit only delivers frames when the screen changes, so the video must resume on
    /// the last frame captured during the pause rather than the stale one from before it.
    @Test func frameCapturedDuringAPauseIsShownFromTheResumePoint() async throws {
        let settings = makeStore()
        settings.frameRate = .fps30

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        for index in 0..<30 {
            assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: CMTime(value: CMTimeValue(index), timescale: 30)))
        }
        assetWriter.pause(at: seconds(1))
        assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: seconds(2)))
        assetWriter.resume(at: seconds(3))

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        // Frames 0 to 29, then the paused frame at 1 s, where the recording resumed
        #expect(result.videoFrameCount == 31)
        let times = try await videoPresentationTimes(of: result.url)
        #expect(times.last == seconds(1))
    }

    /// Audio is cut by the same pause as video. Buffers straddling a pause edge are dropped whole,
    /// so the track is the audio recorded outside the pause, give or take a buffer.
    @Test func pausesAreCutFromTheAudio() async throws {
        let settings = makeStore()
        settings.captureSystemAudio = true
        settings.audioCodec = .pcm

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        // 4 s of 1024-frame buffers, paused from 1 s to 3 s. Each buffer is appended once it has
        // been captured, as ScreenCaptureKit delivers it, so pause and resume land between them.
        for index in 0..<188 {
            if index == 46 { assetWriter.pause(at: seconds(1)) }
            if index == 140 { assetWriter.resume(at: seconds(3)) }
            let presentationTime = CMTime(value: CMTimeValue(index * 1024), timescale: 48000)
            assetWriter.appendAudioSample(try makeSilentAudioSampleBuffer(at: presentationTime))
        }

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        #expect(result.videoFrameCount == 0)
        let duration = try await AVURLAsset(url: result.url).load(.duration).seconds
        #expect(abs(duration - 2) < 0.05)
    }

    /// A microphone that first delivers after a pause is padded up to its place on the cut
    /// timeline, not across the paused time.
    @Test func lateMicrophoneIsNotPaddedAcrossAPause() async throws {
        let settings = makeStore()
        settings.captureSystemAudio = true
        settings.captureMicrophone = true
        settings.audioCodec = .pcm

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        assetWriter.appendAudioSample(try makeSilentAudioSampleBuffer(at: .zero))
        assetWriter.pause(at: seconds(1))
        assetWriter.resume(at: seconds(2))

        // The microphone spins up at 2.5 s, which is 1.5 s into the cut timeline
        let micStart = CMTime(value: 5, timescale: 2)
        for index in 0..<10 {
            let offset = CMTime(value: CMTimeValue(index * 1024), timescale: 48000)
            assetWriter.appendMicrophoneSample(try makeSilentAudioSampleBuffer(at: micStart + offset))
        }

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        let audioTracks = try await AVURLAsset(url: result.url).loadTracks(withMediaType: .audio)
        let microphone = try #require(audioTracks.last)
        let timeRange = try await microphone.load(.timeRange)
        #expect(timeRange.start == .zero)
        // 1.5 s of padding plus 10 buffers
        #expect(abs(timeRange.duration.seconds - (1.5 + 10 * 1024 / 48000.0)) < 0.05)
    }

    @Test func stopWhilePausedKeepsWhatWasRecordedBeforeThePause() async throws {
        let settings = makeStore()
        settings.frameRate = .fps30

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        for index in 0..<60 {
            if index == 30 { assetWriter.pause(at: seconds(1)) }
            assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: CMTime(value: CMTimeValue(index), timescale: 30)))
        }
        #expect(assetWriter.pauseIntervals == [1..<Double.infinity])

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        // Frames up to and including the one at the pause instant
        #expect(result.videoFrameCount == 31)
    }

    /// Nothing was written before the pause, so the first sample after it opens the session.
    @Test func pauseBeforeTheFirstSampleIsDiscarded() async throws {
        let settings = makeStore()
        settings.frameRate = .fps30

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        assetWriter.pause(at: .zero)
        for index in 1..<30 {
            assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: CMTime(value: CMTimeValue(index), timescale: 30)))
        }
        assetWriter.resume(at: seconds(1))
        for index in 30..<60 {
            assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: CMTime(value: CMTimeValue(index), timescale: 30)))
        }
        #expect(assetWriter.pauseIntervals.isEmpty)

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        let times = try await videoPresentationTimes(of: result.url)
        #expect(times == (0..<30).map { CMTime(value: CMTimeValue($0), timescale: 30) })
    }

    private func seconds(_ value: Int) -> CMTime {
        CMTime(value: CMTimeValue(value), timescale: 1)
    }
}
