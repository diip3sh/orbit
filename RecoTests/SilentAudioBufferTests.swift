//
//  SilentAudioBufferTests.swift
//  RecoTests
//

import AVFoundation
import Testing
@testable import Reco

/// Tests for the silence used to pad the head of audio tracks that start late.
struct SilentAudioBufferTests {

    @Test func silenceCoversTheRequestedDuration() throws {
        let format = try makeFormat()
        let duration = CMTime(value: 324, timescale: 1000)

        let buffer = try #require(
            SilentAudioBuffer.make(
                matching: format.formatDescription, duration: duration, at: .zero)
        )

        // 324 ms at 48 kHz
        #expect(CMSampleBufferGetNumSamples(buffer) == 15552)
        #expect(CMSampleBufferGetPresentationTimeStamp(buffer) == .zero)
        #expect(abs(CMSampleBufferGetDuration(buffer).seconds - duration.seconds) < 0.001)
    }

    @Test func silenceMatchesTheSourceFormat() throws {
        let format = try makeFormat()

        let buffer = try #require(
            SilentAudioBuffer.make(
                matching: format.formatDescription,
                duration: CMTime(value: 1, timescale: 10),
                at: .zero)
        )

        let description = try #require(CMSampleBufferGetFormatDescription(buffer))
        let asbd = try #require(
            CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee)

        #expect(asbd.mSampleRate == 48000)
        #expect(asbd.mChannelsPerFrame == 2)
    }

    @Test func samplesAreSilent() throws {
        let format = try makeFormat()

        let buffer = try #require(
            SilentAudioBuffer.make(
                matching: format.formatDescription,
                duration: CMTime(value: 1, timescale: 100),
                at: .zero)
        )

        let blockBuffer = try #require(CMSampleBufferGetDataBuffer(buffer))
        var length = 0
        var pointer: UnsafeMutablePointer<CChar>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length,
            dataPointerOut: &pointer)

        #expect(status == noErr)
        #expect(length > 0)

        let bytes = try #require(pointer)
        let nonZero = (0..<length).contains { bytes[$0] != 0 }
        #expect(nonZero == false)
    }

    @Test func honoursThePresentationTime() throws {
        let format = try makeFormat()
        let presentationTime = CMTime(value: 5, timescale: 100)

        let buffer = try #require(
            SilentAudioBuffer.make(
                matching: format.formatDescription,
                duration: CMTime(value: 1, timescale: 100),
                at: presentationTime)
        )

        #expect(CMSampleBufferGetPresentationTimeStamp(buffer) == presentationTime)
    }

    @Test(arguments: [CMTime.zero, CMTime(value: -1, timescale: 10), CMTime.invalid])
    func rejectsNonPositiveDurations(duration: CMTime) throws {
        let format = try makeFormat()

        #expect(
            SilentAudioBuffer.make(
                matching: format.formatDescription, duration: duration, at: .zero) == nil
        )
    }

    @Test func rejectsDurationsShorterThanOneFrame() throws {
        let format = try makeFormat()

        // Well under half a sample period at 48 kHz, so it rounds to zero frames
        #expect(
            SilentAudioBuffer.make(
                matching: format.formatDescription,
                duration: CMTime(value: 1, timescale: 1_000_000),
                at: .zero) == nil
        )
    }

    // MARK: - Helpers

    private func makeFormat() throws -> AVAudioFormat {
        try #require(
            AVAudioFormat(
                commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 2, interleaved: true)
        )
    }
}
